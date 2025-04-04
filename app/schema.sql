CREATE TABLE IF NOT EXISTS deck (
    id VARCHAR(32) PRIMARY KEY,
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    meta VARCHAR(4096)
);

CREATE TABLE IF NOT EXISTS card (
    id VARCHAR(32) PRIMARY KEY,
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    meta VARCHAR(4096),
    deckId VARCHAR(32),
    FOREIGN KEY (deckId) REFERENCES deck(id) ON DELETE SET NULL
);
