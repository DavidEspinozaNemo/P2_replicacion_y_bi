CREATE TABLE ME_STORE(
	id_store INT,
	city VARCHAR ( 50 ) NOT NULL,
	country VARCHAR ( 50 ) NOT NULL,
	PRIMARY KEY (id_store)
);

CREATE TABLE ME_TIME(
	id_time INT,
	fecha date NOT NULL,
	_day NUMERIC(2) NOT NULL,
	_mounth NUMERIC(2) NOT NULL,
	_year NUMERIC(4) NOT NULL,
	PRIMARY KEY (id_time)
);

CREATE TABLE ME_FILM(
	id_film INT,
	name_category VARCHAR ( 150 ) NOT NULL,
	film_title VARCHAR ( 255 ) NOT NULL,
	PRIMARY KEY (id_film)
);

CREATE TABLE ME_RENTAL(
	id_rental INT,
	id_film INT,
	id_store INT,
	id_time INT,
	amount numeric(5,2) NOT NULL,
	PRIMARY KEY (id_rental),
	FOREIGN KEY (id_film)
      REFERENCES ME_FILM (id_film),
	FOREIGN KEY (id_store)
      REFERENCES ME_STORE (id_store),
	FOREIGN KEY (id_time)
      REFERENCES ME_TIME (id_time)
);

CREATE TABLE ME_ACTOR(
	id_register SERIAL PRIMARY KEY,
	id_actor INT,
	id_film INT NOT NULL,
	first_name VARCHAR ( 45 ) NOT NULL,
	last_name VARCHAR ( 45 ) NOT NULL
);

SELECT pg_get_serial_sequence('ME_ACTOR', 'id_register');
ALTER SEQUENCE public.me_actor_id_register_seq RENAME TO seq_me_actor_id;
SELECT setval('seq_me_actor_id', 1, false);

DROP TABLE IF EXISTS ME_STORE,ME_TIME,ME_FILM,ME_RENTAL,ME_ACTOR;

CREATE OR REPLACE FUNCTION insert_data_store()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_store (id_store, city, country)
		SELECT st.store_id, ct.city, cn.country
		FROM store as st
		INNER JOIN address as adr ON st.address_id = adr.address_id
		INNER JOIN city as ct ON adr.city_id = ct.city_id
		INNER JOIN country as cn ON ct.country_id = cn.country_id
		ON CONFLICT DO NOTHING; -- omite insersiones con conflicto
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_time()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_time (id_time, fecha, _day, _mounth, _year)
		SELECT rt.rental_id, rt.return_date ,extract(day from rt.return_date),
		  extract(month from rt.return_date), extract(year from rt.return_date)
		FROM rental as rt
		WHERE rt.return_date IS NOT NULL
		ON CONFLICT DO NOTHING; -- omite insersiones con conflicto
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_film()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_film (id_film, name_category, film_title)
		select film.film_id, film.title, category.name
		from film
		inner join film_category on film.film_id = film_category.film_id
		inner join category on film_category.category_id = category.category_id
		ON CONFLICT DO NOTHING; -- omite insersiones con conflicto
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_rental()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_rental (id_rental, id_film, id_store, id_time, amount)
		SELECT rt.rental_id, iv.film_id, st.store_id, me_time.id_time, py.amount
		FROM rental as rt 
		INNER JOIN payment as py on rt.rental_id = py.rental_id
		INNER JOIN inventory as iv on rt.inventory_id = iv.inventory_id
		INNER JOIN film as fl on iv.film_id = fl.film_id
		INNER JOIN staff as sf on rt.staff_id = sf.staff_id
		INNER JOIN store as st on sf.store_id = st.store_id
		INNER JOIN me_time on me_time.id_time = rt.rental_id
		ON CONFLICT DO NOTHING; -- omite insersiones con conflicto
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_actor()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_actor (id_actor, id_film, first_name, last_name)
		select actor.actor_id, film.film_id, actor.first_name, actor.last_name
		from film
		inner join film_actor on film_actor.film_id = film.film_id
		inner join actor on actor.actor_id = film_actor.actor_id
		order by film.film_id
		ON CONFLICT DO NOTHING; -- omite insersiones con conflicto
END;
$$ LANGUAGE plpgsql;

select insert_data_store();
select insert_data_time();
select insert_data_film();
select insert_data_rental();
select insert_data_actor();
