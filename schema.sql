CREATE EXTENSION pgcrypto;

CREATE TABLE users(
  username varchar(18) UNIQUE NOT NULL,
  pass text NOT NULL
);

CREATE TABLE posts(
  id serial PRIMARY KEY,
  song_link text NOT NULL,
  caption varchar(140),
  time_of timestamp DEFAULT NOW() NOT NULL,
  username varchar(18) REFERENCES users(username) NOT NULL  
);

CREATE TABLE comments(
  id serial PRIMARY KEY,
  comment varchar(140) NOT NULL,
  time_of timestamp DEFAULT NOW() NOT NULL,
  post_id integer REFERENCES posts(id),
  username varchar(18) REFERENCES users(username)
);

CREATE TABLE likes(
  username varchar(18) REFERENCES users(username) ON DELETE CASCADE NOT NULL,
  post_id integer REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  time_of timestamp DEFAULT NOW() NOT NULL,
  UNIQUE(username, post_id)
);

CREATE TABLE follows(
  username varchar(18) REFERENCES users(username),
  follower varchar(18) REFERENCES users(username),
  time_of timestamp DEFAULT NOW() NOT NULL,
  UNIQUE(username, follower)
);