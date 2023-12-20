package main

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	"github.com/posener/cmd"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func main() {
	root := cmd.New()
	port := root.String("port", "8080", "Listen Port")
	debug := root.Bool("debug", false, "Debug logging")
	_ = root.Parse()

	zerolog.SetGlobalLevel(zerolog.InfoLevel)
	if *debug {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	}

	router := mux.NewRouter()
	router.HandleFunc("/", reverseOriginIp)
	log.Info().Msgf("Starting Server on port: %s", *port)
	err := http.ListenAndServe(fmt.Sprintf(":%s", *port), router)
	if err != nil {
		log.Error().Msg("Something went wrong. Exiting.")
		panic(err)
	}
}

func reverseOriginIp(w http.ResponseWriter, r *http.Request) {

	client_ip := r.Header.Get("X-Forwarded-For")
	if client_ip != "" {
		client_ip = strings.Split(client_ip, ",")[0]
	} else {
		client_ip = strings.Split(r.RemoteAddr, ":")[0]
	}

	result := string(reverseSlice([]rune(client_ip)))

	_, err := fmt.Fprint(w, result)
	if err != nil {
		log.Error().Msg("Something Went Wrong.")
		w.WriteHeader(http.StatusInternalServerError)
	}
}

func reverseSlice[T comparable](s []T) []T {
	for i, j := 0, len(s)-1; i < j; i, j = i+1, j-1 {
		s[i], s[j] = s[j], s[i]
	}
	return s
}
