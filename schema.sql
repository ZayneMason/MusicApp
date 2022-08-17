CREATE TABLE users(
  id serial PRIMARY KEY,
  email varchar(30) UNIQUE NOT NULL,
  pass text NOT NULL
);

CREATE TABLE posts(
  id serial PRIMARY KEY,
  song_link text NOT NULL,
  caption text,
  user_id integer REFERENCES users(id) NOT NULL 
);

CREATE TABLE comments(
  id serial PRIMARY KEY,
  comment varchar(140) NOT NULL,
  post_id integer REFERENCES posts(id),
  user_id integer REFERENCES users(id)
);

CREATE TABLE likes(
  user_id integer REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  post_id integer REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  UNIQUE(user_id, post_id)
);