package db

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/sqlite3"
	"github.com/golang-migrate/migrate/v4/source/file"
)

func Open(dbPath string) (*sql.DB, error) {
	if dbPath == "" {
		return nil, errors.New("db path is empty")
	}
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("create db dir: %w", err)
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	if _, err := db.Exec("PRAGMA foreign_keys = ON;"); err != nil {
		return nil, fmt.Errorf("pragma foreign_keys: %w", err)
	}
	if _, err := db.Exec("PRAGMA journal_mode = WAL;"); err != nil {
		return nil, fmt.Errorf("pragma journal_mode: %w", err)
	}
	if _, err := db.Exec("PRAGMA synchronous = NORMAL;"); err != nil {
		return nil, fmt.Errorf("pragma synchronous: %w", err)
	}

	return db, nil
}

func RunMigrations(dbPath, migrationsPath string) error {
	if migrationsPath == "" {
		return errors.New("migrations path is empty")
	}

	absPath, err := filepath.Abs(migrationsPath)
	if err != nil {
		return fmt.Errorf("abs migrations path: %w", err)
	}

	srcURL := "file://" + filepath.ToSlash(absPath)
	sourceDriver, err := (&file.File{}).Open(srcURL)
	if err != nil {
		return fmt.Errorf("open migrations source: %w", err)
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return fmt.Errorf("open sqlite for migrate: %w", err)
	}
	defer db.Close()

	dbDriver, err := sqlite3.WithInstance(db, &sqlite3.Config{})
	if err != nil {
		return fmt.Errorf("sqlite3 migrate driver: %w", err)
	}

	m, err := migrate.NewWithInstance("file", sourceDriver, "sqlite3", dbDriver)
	if err != nil {
		return fmt.Errorf("migrate init: %w", err)
	}

	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migrate up: %w", err)
	}
	_, _ = m.Close()

	return nil
}
