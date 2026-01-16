# Security

Rookery has been designed with security in mind. This document outlines the security measures implemented.

## Security Features

### Input Validation
- **Title**: 1-200 characters, non-empty
- **Code**: 1-100,000 characters
- **Language**: Must be from allowed whitelist
- **Description**: Max 1,000 characters
- **Tags**: Max 20 tags, each max 50 characters

### Rate Limiting
- 100 requests per minute per IP address
- Returns `429 Too Many Requests` with `Retry-After` header when exceeded

### SQL Injection Prevention
- All database queries use Fluent ORM with parameterized queries
- Search functionality uses safe operators (`~~`) instead of raw SQL

### XSS Prevention
- HTML escaping in syntax highlighter output
- Language parameter sanitization

### Command Injection Prevention
- Freeze service uses strict whitelists for themes and languages
- Path traversal protection for file operations
- Process timeouts (10 seconds) to prevent resource exhaustion

## Allowed Languages

```
bash, c, clojure, cpp, csharp, css, elixir, go, haskell, html,
java, javascript, json, kotlin, lua, markdown, perl, php,
python, ruby, rust, scala, sh, sql, swift, typescript, xml, yaml
```

## Allowed Freeze Themes

```
catppuccin-mocha, dracula, github-dark, github-light, gruvbox,
gruvbox-light, monokai, nord, one-dark, one-light, solarized-dark,
solarized-light, tokyonight, vim-dark, vim-light, zenburn
```

## Reporting Security Issues

If you discover a security vulnerability, please report it responsibly by opening a GitHub issue or contacting the maintainers directly.

## Future Enhancements

- [ ] User authentication
- [ ] Authorization/access control
- [ ] HTTPS enforcement (deployment concern)
- [ ] Database encryption
