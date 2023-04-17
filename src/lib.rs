mod query;
use futures::future;
use mlua::prelude::{Lua, LuaResult, LuaTable};
use reqwest::header;
use reqwest_middleware::{ClientBuilder, ClientWithMiddleware};
use reqwest_retry::{policies::ExponentialBackoff, RetryTransientMiddleware};
use serde::{Deserialize, Serialize};
use std::{
    env,
    error::Error,
    fs::{self, File},
    io::Cursor,
    path::PathBuf,
};
use tokio::task::JoinHandle;

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
fn get_headers(token: &str) -> header::HeaderMap {
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
    headers
}

fn get_github_request_client() -> Result<ClientWithMiddleware, Box<dyn Error>> {
    // Retry up to 3 times with increasing intervals between attempts.
    let retry_policy = ExponentialBackoff::builder().build_with_max_retries(3);
    let client = ClientBuilder::new(reqwest::Client::new())
        .with(RetryTransientMiddleware::new_with_policy(retry_policy))
        .build();
        // .map_err(|e| Box::new(e) as Box<dyn Error>)
    Ok(client)
}

fn cleanup_temp_files() -> Result<(), Box<dyn Error>> {
    let dir = env::temp_dir().join("nvimghs");
    if dir.exists() {
        fs::remove_dir_all(dir)?;
    }
    Ok(())
}

async fn download_file<'a, 'b>(
    url: String,
    filename: String,
    token: String,
) -> Result<PathBuf, Box<dyn Error>> {
    let headers = get_headers(&token); 
    let client = get_github_request_client()?;
    let dir = env::temp_dir().join("nvimghs");
    fs::create_dir_all(&dir)?;
    let res = client.get(&url)
        .headers(headers)
        .send().await?;
    if !res.status().is_success() {
        let search_error = res
            .json::<GithubAPIError>()
            .await
            .expect("failed to parse error from github download response");
        return Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Github responded with an error: {}", search_error.message),
        )));
    }
    let download_res = res
        .json::<DownloadResponse>()
        .await
        .expect("failed to parse json from github download response");
    let headers = get_headers(&token);
    let res = client
        .get(download_res.download_url)
        .headers(headers) 
        .send().await?;
    let digest = md5::compute(url);
    let temp_file_name = format!("{:x}-{}", digest, filename);
    let path = dir.join(temp_file_name);
    if path.exists() {
        return Ok(path);
    }
    let mut file = File::create(path.clone())?;
    let mut content = Cursor::new(res.bytes().await.unwrap());
    std::io::copy(&mut content, &mut file)?;
    Ok(path)
}
async fn request_codesearch(
    query: &str,
    url: &str,
    token: &str,
) -> Result<SearchResults, Box<dyn Error>> {
    let headers = get_headers(token);
    let client = get_github_request_client()?;
    let query = urlencoding::encode(query);
    let res = client
        .get(format!("{}/search/code?q={}", url, query))
        .headers(headers)
        .send()
        .await?;
    if !res.status().is_success() {
        let search_error = res
            .json::<GithubAPIError>()
            .await
            .expect("failed to parse error from github search response");
        return Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Github responded with an error: {}", search_error.message),
        )));
    }
    let results = res
        .json::<SearchResults>()
        .await
        .expect("failed to parse json from github search response");
    Ok(results)
}

#[tokio::main]
async fn search_and_download_results<'a>(
    lua: &'a Lua,
    args: LuaTable,
) -> Result<LuaTable<'a>, Box<dyn Error>> {
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
    let results = request_codesearch(&query, &url, &token).await;

    let lua_table = lua.create_table()?;
    if let Err(err) = results {
        lua_table.set("error", err.to_string())?;
        return Ok(lua_table);
    }
    let results = results.unwrap();
    let tasks: Vec<JoinHandle<_>> = results
        .items
        .iter()
        .map(|item| {
            (
                item.url.to_string(),
                item.name.to_string(),
                token.to_string(),
            )
        })
        .map(|(url, name, token)| {
            tokio::spawn(async move {
                download_file(url.to_string(), name, token)
                    .await
                    .map_err(|e| {
                        std::io::Error::new(
                            std::io::ErrorKind::Other,
                            format!("failed to download file from url:{} {}", url, e),
                        )
                    })
            })
        })
        .collect::<Vec<_>>();
    let task_results = future::join_all(tasks).await;
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
        // this is the name display value for all search result items
        lua_item.set(
            "result_entry_full_name",
            format!("{}: {}", item.repository.full_name, item.path),
        )?;
        let download = task_results
            .get(i)
            .unwrap()
            .as_ref()
            .expect("failed to get refrence from task result");
        if let Err(err) = download {
            lua_item.set("error", err.to_string())?;
        } else {
            let download = download
                .as_ref()
                .expect("failed to get refrence from task result");
            // this is the path to the downloaded file to be used in previews / buffer open commands
            lua_item.set("downloaded_local_path", download.to_str())?;
        }
        lua_table.set(i + 1, lua_item)?;
    }
    Ok(lua_table)
}
#[mlua::lua_module]
fn libgithub_search(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    let cleanup_fn = lua
        .create_function(|_, ()| {
            cleanup_temp_files().expect("failed to cleanup temp files");
            Ok(())
        })
        .unwrap();
    exports
        .set("cleanup", cleanup_fn)
        .expect("failed to create lua cleanup_fn");
    let search_fn = lua
        .create_async_function(|lua, args: LuaTable| async move {
            Ok(search_and_download_results(lua, args).unwrap())
        })
        .expect("failed to create lua search_fn");
    exports
        .set("request_codesearch", search_fn)
        .expect("failed to set search_fn on exported lua table");
    Ok(exports)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    #[tokio::test]
    async fn request_codesearch_returns_results() {
        let result =
            request_codesearch("test", "https://api.github.com", env!("GIT_NPM_AUTH_TOKEN")).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn download_file_returns_path() {
        let url = "https://api.github.com/repositories/683527/contents/test.data/positiveUpdate/ObsInjectionsData.test?ref=9fe69622a29a3f1a230254018271a3187b54db56";
        let result = download_file(
            url.to_string(),
            "manifest.txt".to_string(),
            env!("GIT_NPM_AUTH_TOKEN").to_string(),
        )
        .await;
        println!("result: {:?}", result);
        assert!(result.is_ok());
    }
}
