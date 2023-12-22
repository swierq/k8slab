package main

import (
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gorilla/mux"
	"github.com/posener/cmd"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type ReverseIP struct {
	gorm.Model
	ReverseIP string
}

func main() {
	root := cmd.New()

	port := root.String("port", "8080", "Listen Port")
	debug := root.Bool("debug", false, "Debug logging")
	_ = root.Parse()

	zerolog.SetGlobalLevel(zerolog.InfoLevel)
	if *debug {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	}

	dbUrl := os.Getenv("POSTGRES_URL")
	dbPass := os.Getenv("POSTGRES_PASS")
	dbUser := os.Getenv("POSTGRES_USER")
	dbName := os.Getenv("POSTGRES_DBNAME")

	dbHost := ""
	dbPort := ""
	dbHostPort := strings.Split(dbUrl, ":")
	if len(dbHostPort) == 2 {
		dbHost = dbHostPort[0]
		dbPort = dbHostPort[1]
	}

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s", dbHost, dbUser, dbPass, dbName, dbPort)
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		// panic("failed to connect database")
		log.Error().Msg("Could not connect to DB, disabling history.")
		db = nil
	}
	if db != nil {
		err := db.AutoMigrate(&ReverseIP{})
		if err != nil {
			log.Error().Msg("Could not migrate DB schema, disabling history.")
			db = nil
		}
	}

	router := mux.NewRouter()
	router.HandleFunc("/", reverseOriginIp(db))
	router.HandleFunc("/history", reverseOriginIpHistory(db))
	log.Info().Msgf("Starting Server on port: %s", *port)
	err = http.ListenAndServe(fmt.Sprintf(":%s", *port), router)
	if err != nil {
		log.Error().Msg("Something went wrong. Exiting.")
		panic(err)
	}
}

func reverseOriginIp(db *gorm.DB) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		client_ip := r.Header.Get("X-Forwarded-For")
		if client_ip != "" {
			client_ip = strings.Split(client_ip, ",")[0]
		} else {
			client_ip = strings.Split(r.RemoteAddr, ":")[0]
		}

		result := string(reverseSlice([]rune(client_ip)))
		if db != nil {
			db.Create(&ReverseIP{ReverseIP: result})
		}
		_, err := fmt.Fprint(w, result)
		if err != nil {
			log.Error().Msg("Something Went Wrong.")
			w.WriteHeader(http.StatusInternalServerError)
		}
	}
}

func reverseOriginIpHistory(db *gorm.DB) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		var reverseIPS []ReverseIP
		result := ""
		if db != nil {
			_ = db.Find(&reverseIPS)
			for _, v := range reverseIPS {
				result = fmt.Sprintf("%s\n%s", result, v.ReverseIP)
			}
		} else {
			result = "DB history logging is disabled."
		}
		_, err := fmt.Fprint(w, result)
		if err != nil {
			log.Error().Msg("Something Went Wrong.")
			w.WriteHeader(http.StatusInternalServerError)
		}
	}
}

func reverseSlice[T comparable](s []T) []T {
	for i, j := 0, len(s)-1; i < j; i, j = i+1, j-1 {
		s[i], s[j] = s[j], s[i]
	}
	return s
}
