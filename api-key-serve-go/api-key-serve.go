package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"chef-role": { "token": "s.yeGpBxRr9BrU5WK6wg34Ub0U"}}`)
}

func main() {
	// Set up binding
	listenAddr := "127.0.0.1"
	listenPort := "10811"
	listenBind := fmt.Sprintf("%s:%s", listenAddr, listenPort)
	// Run HTTP server
	logger := log.New(os.Stdout, "http: ", log.LstdFlags)
	logger.Println(fmt.Sprintf("Server is starting up at http://%s", listenBind))
	http.HandleFunc("/", handler)
	http.ListenAndServe(listenBind, nil)
}
