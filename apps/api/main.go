package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"example.com/hello-go/handlers"
	"example.com/hello-go/middleware"
	"example.com/hello-go/store"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	port := env("PORT", "8080")
	dbPath := env("DB_PATH", "app.db")

	db, err := store.Open(dbPath)
	if err != nil {
		log.Fatal(err)
	}

	h := &handlers.Users{DB: db}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /users", h.List)
	mux.HandleFunc("GET /users/{id}", h.Get)
	mux.HandleFunc("POST /users", h.Create)
	mux.HandleFunc("PUT /users/{id}", h.Update)

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: middleware.Logging(middleware.CORS(mux)),
	}

	go func() {
		log.Printf("listening on :%s", port)
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt) // catch Ctrl+C
	<-stop                            // block here until it happens

	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	srv.Shutdown(ctx) // finish active requests, refuse new ones
	db.Close()
}
