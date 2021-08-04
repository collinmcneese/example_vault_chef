# api-key-serve-go

This is a simple golang app which serves the content:

```json
{"chef-role": { "token": "some_token"}}
```

* Can be launched using `go run api-key-serve-go/api-key-serve.go` from the root of the repository
* Configured to listen on port `:10811` which is what the Test Kitchen suite `secret-from-api` is configured to use for polling the token data.
