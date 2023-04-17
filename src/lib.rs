mod query;
use mlua::prelude::{Lua, LuaResult, LuaTable};
use reqwest::header;
use serde::{Deserialize, Serialize};
use std::{env, error::Error, fs::File, io::Cursor, path::PathBuf, thread};

#[derive(Default, Debug, Clone, PartialEq, Deserialize, Serialize)]
struct SearchResults {
    total_count: u32,
    incomplete_results: bool,
    items: Vec<SearchResult>,
}

#[derive(Default, Debug, Clone, PartialEq, Deserialize, Serialize)]
struct GithubAPIError {
    message: String,
}

#[derive(Default, Debug, Clone, PartialEq, Deserialize, Serialize)]
struct SearchResult {
    name: String,
    path: String,
    sha: String,
    url: String,
    git_url: String,
    html_url: String,
    score: f32,
    repository: Repository,
}

#[derive(Default, Debug, Clone, PartialEq, Deserialize, Serialize)]
struct Repository {
    name: String,
    full_name: String,
}

#[derive(Default, Debug, Clone, PartialEq, Deserialize, Serialize)]
struct DownloadResponse {
    download_url: String,
}

fn get_github_request_client(token: &str) -> Result<reqwest::blocking::Client, Box<dyn Error>> {
    let mut headers = header::HeaderMap::new();
    let token_header = format!("Bearer {}", token);
    headers.insert(
        "Authorization",
        header::HeaderValue::from_str(&token_header)
            .expect("failed to format authroization header"),
    );
    headers.insert(
        "X-GitHub-Api-Version",
        header::HeaderValue::from_static("2022-11-28"),
    );
    headers.insert(
        "User-Agent",
        header::HeaderValue::from_static("nvim-github-codesearch"),
    );
    reqwest::blocking::Client::builder()
        .default_headers(headers)
        .build()
        .map_err(|e| Box::new(e) as Box<dyn Error>)
}
fn download_file(url: &str, filename: &str, token: &str) -> Result<PathBuf, Box<dyn Error>> {
    let client = get_github_request_client(token)?;
    let dir = env::temp_dir(); //.join("nvimghs");
                               //TODO
                               // if ! dir.exists() {
                               //     dir.create_dir()?;
                               // }
    let res = client.get(url).send()?;
    if !res.status().is_success() {
        let search_error = res
            .json::<GithubAPIError>()
            .expect("failed to parse error from github download response");
        return Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Github responded with an error: {}", search_error.message),
        )));
    }
    let download_res = res
        .json::<DownloadResponse>()
        .expect("failed to parse json from github download response");
    let res = client.get(download_res.download_url).send()?;
    let digest = md5::compute(url);
    let temp_file_name = format!("{:x}-{}", digest, filename);
    let path = dir.join(temp_file_name);
    if path.exists() {
        return Ok(path);
    }
    let mut file = File::create(path.clone())?;
    let mut content = Cursor::new(res.bytes().unwrap());
    std::io::copy(&mut content, &mut file)?;
    Ok(path)
}
fn request_codesearch(
    query: &str,
    url: &str,
    token: &str,
) -> Result<SearchResults, Box<dyn Error>> {
    let client = get_github_request_client(token)?;
    let query = urlencoding::encode(query);
    let res = client
        .get(format!("{}/search/code?q={}", url, query))
        .send()?;
    if !res.status().is_success() {
        let search_error = res
            .json::<GithubAPIError>()
            .expect("failed to parse error from github search response");
        return Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Github responded with an error: {}", search_error.message),
        )));
    }
    // println!("requesting {}", res.text().unwrap());
    let results = res
        .json::<SearchResults>()
        .expect("failed to parse json from github search response");
    Ok(results)
}

#[mlua::lua_module]
fn libgithub_search(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let search_fn = lua
        .create_async_function(async |lua, args: LuaTable| {
            let query = args.get::<_, String>("query")?;
            let url = args.get::<_, String>("url")?;
            let token = args.get::<_, String>("token")?;
            let parsed_query = query::SearchQuery::from_query_string(&query);
            if let Err(err) = parsed_query {
                let lua_table = lua.create_table()?;
                lua_table.set("error", err.to_string())?;
                return Ok(lua_table);
            }
            let parsed_query = parsed_query.unwrap();
            let results = request_codesearch(&query, &url, &token);

            let lua_table = lua.create_table()?;
            if let Err(err) = results {
                lua_table.set("error", err.to_string())?;
                return Ok(lua_table);
            }
            let results = results.unwrap();
            for (i, item) in results.items.iter().enumerate() {
                let lua_item = lua.create_table()?;
                lua_item.set("name", item.name.to_string())?;
                lua_item.set("path", item.path.to_string())?;
                lua_item.set("sha", item.sha.to_string())?;
                lua_item.set("url", item.url.to_string())?;
                lua_item.set("git_url", item.git_url.to_string())?;
                lua_item.set("html_url", item.html_url.to_string())?;
                lua_item.set("score", item.score)?;
                lua_item.set("original_search_term", parsed_query.search_term.to_string())?;
                let download = download_file(&item.url, &item.name, &token).unwrap();
                lua_item.set(
                    "downloaded_local_path",
                        download.to_str()
                )?;
                lua_item.set(
                    "result_entry_full_name",
                    format!("{}: {}", item.repository.full_name, item.path),
                )?;
                lua_table.set(i + 1, lua_item)?;
            }

            // results.items.iter().for_each(|item| {
            // });
            Ok(lua_table)
        })
        .expect("failed to create lua search_fn");

    let download_fn = lua
        .create_function(|lua, args: LuaTable| {
            let download_url = args.get::<_, String>("download_url")?;
            let filename = args.get::<_, String>("filename")?;
            let token = args.get::<_, String>("token")?;
            let results = download_file(&download_url, &filename, &token);
            let lua_table = lua.create_table()?;
            if let Err(err) = results {
                lua_table.set("error", err.to_string())?;
                return Ok(lua_table);
            }
            let results = results.unwrap();
            lua_table.set("path", results.to_str().unwrap())?;
            Ok(lua_table)
        })
        .expect("failed to create lua download_fn");
    exports
        .set("request_codesearch", search_fn)
        .expect("failed to set search_fn on exported lua table");
    exports
        .set("download", download_fn)
        .expect("failed to set download_fn on exported lua table");
    Ok(exports)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    // #[test]
    // fn request_codesearch_returns_results() {
    //     let result =
    //         request_codesearch("test", "https://api.github.com", env!("GIT_NPM_AUTH_TOKEN"));
    //     assert!(result.is_ok());
    // }
    // #[test]
    // fn download_file_returns_path() {
    //     let url = "https://api.github.com/repositories/683527/contents/test.data/positiveUpdate/ObsInjectionsData.test?ref=9fe69622a29a3f1a230254018271a3187b54db56";
    //     let result = download_file(url, "manifest.txt", env!("GIT_NPM_AUTH_TOKEN"));
    //     println!("result: {:?}", result);
    //     assert!(result.is_ok());
    // }
}
// :lua require('user.utils').print(require("libgithub_search").scopes)
