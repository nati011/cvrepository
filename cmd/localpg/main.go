// Local embedded Postgres for dev when Docker is unavailable (port 5433).
package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
)

func main() {
	runtime := ".local/pg/runtime"
	data := ".local/pg/data"
	bin := ".local/pg/bin"
	_ = os.MkdirAll(runtime, 0o750)
	_ = os.MkdirAll(data, 0o750)
	_ = os.MkdirAll(bin, 0o750)

	db := embeddedpostgres.NewDatabase(
		embeddedpostgres.DefaultConfig().
			Username("cvrepo").
			Password("cvrepo").
			Database("cvrepo").
			Version(embeddedpostgres.V16).
			Port(5433).
			RuntimePath(runtime).
			DataPath(data).
			BinariesPath(bin),
	)
	if err := db.Start(); err != nil {
		log.Fatalf("embedded postgres: %v", err)
	}
	log.Println("embedded postgres listening on 127.0.0.1:5433")
	defer db.Stop()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig
}
