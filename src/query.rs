use std::{collections::HashMap, error::Error};

use regex::Regex;

pub struct SearchQuery {
    pub search_term: String,
    pub restrictions: HashMap<String, String>,
}

impl SearchQuery {
    fn parse_search_term(query: &str) -> Result<String, Box<dyn Error>> {
        let re = Regex::new(r"([a-zA-Z0-9\-_]+):").unwrap();
        let tokens = re.split(query).collect::<Vec<&str>>();
        let term = tokens.first();
        if let Some(term) = term {
            return Ok(term.trim().to_string());
        }
        Err(Box::new(std::io::Error::new(
            std::io::ErrorKind::Other,
            "failed to parse search term",
        )))
    }
    fn parse_restrictions(query: &str) -> Result<HashMap<String, String>, Box<dyn Error>> {
        let re = Regex::new(r"([a-zA-Z0-9\-_]+):([\S]+)").unwrap();
        let restrictions: HashMap<String, String> = re
            .captures_iter(query)
            .map(|cap| {
                let key = cap.get(1).unwrap().as_str().to_string();
                let value = cap.get(2).unwrap().as_str().to_string();
                (key, value)
            })
            .collect::<HashMap<String, String>>();
        Ok(restrictions)
    }
    pub fn from_query_string(query: &str) -> Result<Self, Box<dyn Error>> {
        Ok(Self {
            search_term: Self::parse_search_term(query)?,
            restrictions: Self::parse_restrictions(query)?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_parse_search_term() {
        let query = "foo bar language:rust";
        let term = SearchQuery::from_query_string(query).unwrap();
        assert_eq!(term.search_term, "foo bar");
        assert_eq!(term.restrictions["language"], "rust");
    }
    #[test]
    fn test_parse_search_term_multiple_restrictions() {
        let query = "foo bar language:rust user:alvin";
        let term = SearchQuery::from_query_string(query).unwrap();
        assert_eq!(term.search_term, "foo bar");
        assert_eq!(term.restrictions["language"], "rust");
        assert_eq!(term.restrictions["user"], "alvin");
    }
}
