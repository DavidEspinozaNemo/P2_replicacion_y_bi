CREATE TABLE ME_CATEGORY(
	id_category INT,
	name VARCHAR ( 25 ) NOT NULL,
	PRIMARY KEY (id_category)
);

CREATE TABLE ME_STORE(
	id_store INT,
	city VARCHAR ( 50 ) NOT NULL,
	country VARCHAR ( 50 ) NOT NULL,
	PRIMARY KEY (id_store)
);

CREATE TABLE ME_TIME(
	id_time INT,
	_mounth NUMERIC(2) NOT NULL,
	_year NUMERIC(4) NOT NULL,
	PRIMARY KEY (id_time)
);

CREATE TABLE ME_FILM(
	id_film INT,
	id_category INT,
	film_title VARCHAR ( 255 ) NOT NULL,
	PRIMARY KEY (id_film),
	FOREIGN KEY (id_category)
      REFERENCES ME_CATEGORY (id_category)
);

CREATE TABLE ME_ACTOR(
	id_register SERIAL PRIMARY KEY,
	id_actor INT,
	id_film INT,
	first_name VARCHAR ( 45 ) NOT NULL,
	last_name VARCHAR ( 45 ) NOT NULL,
	FOREIGN KEY (id_film)
      REFERENCES ME_FILM (id_film)
);

SELECT pg_get_serial_sequence('ME_ACTOR', 'id_register');
ALTER SEQUENCE public.me_actor_id_register_seq RENAME TO seq_me_actor_id;
SELECT setval('seq_me_actor_id', 1, false);

CREATE TABLE ME_RENTAL(
	id_rental INT,
	id_film INT,
	id_store INT,
	id_time INT,
	amount numeric(5,2) NOT NULL,
	FOREIGN KEY (id_film)
      REFERENCES ME_FILM (id_film),
	FOREIGN KEY (id_store)
      REFERENCES ME_STORE (id_store),
	FOREIGN KEY (id_time)
      REFERENCES ME_TIME (id_time)
);

DROP TABLE IF EXISTS ME_CATEGORY,ME_STORE,ME_TIME,ME_FILM,ME_ACTOR,ME_RENTAL;

-- funciones llenado
CREATE OR REPLACE FUNCTION insert_data_category()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_category (id_category, name)
		SELECT ct.category_id, ct.name
		FROM category as ct
		WHERE NOT EXISTS (
		   SELECT 1 FROM me_category
		   WHERE id_category = ct.category_id
		);
END;
$$ LANGUAGE plpgsql;

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
		WHERE NOT EXISTS (
		   SELECT 1 FROM me_store
		   WHERE id_store = st.store_id
		);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_time()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_time (id_time, _mounth, _year)
		SELECT rt.rental_id, extract(month from rt.return_date), extract(year from rt.return_date)
		FROM rental as rt
		WHERE rt.return_date IS NOT NULL
		AND NOT EXISTS (
		   SELECT 1 FROM me_time
		   WHERE id_time = rt.rental_id
		);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_film()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_film (id_film, id_category, film_title)
		SELECT fl.film_id, flca.category_id, fl.title
		FROM film as fl
		INNER JOIN film_category as flca ON fl.film_id = flca.film_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insert_data_actor()
RETURNS VOID AS $$
DECLARE
  numero_error NUMERIC := 123;
BEGIN
	INSERT INTO me_actor (id_actor, id_film, first_name, last_name)
		SELECT ac.actor_id, fl.film_id, ac.first_name, ac.last_name
		FROM actor as ac
		INNER JOIN film_actor as flac ON ac.actor_id = flac.actor_id
		INNER JOIN film as fl ON flac.film_id = fl.film_id;
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
		INNER JOIN me_time on me_time.id_time = rt.rental_id;
END;
$$ LANGUAGE plpgsql;

select insert_data_category();
select insert_data_store();
select insert_data_time();
select insert_data_film();
select insert_data_actor();
select insert_data_rental();

-- las ventas por mes
select sum(me_rental.amount), me_time._mounth
	from me_rental 
	inner join me_time on me_rental.id_time = me_time.id_time
	group by me_time._mounth
	order by me_time._mounth;