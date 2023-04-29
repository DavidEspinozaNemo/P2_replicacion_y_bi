/*
Procedimiento: insert_customer

Parametros:

store_id: el identificador de la tienda a la que pertenece el cliente.
first_name: el nombre del cliente.
last_name: el apellido del cliente.
email: el correo electrónico del cliente.
address: la dirección del cliente.
address2: la segunda línea de dirección del cliente.
district: el distrito del cliente.
city: la ciudad del cliente.
country: el país del cliente.
postal_code: el código postal del cliente.
phone: el número de teléfono del cliente.

Descripcion: 
Este procedimiento inserta un nuevo cliente, junto con su dirección, ciudad y país correspondientes.
*/

CREATE OR REPLACE PROCEDURE insert_customer(
    IN store_id integer, 
    IN first_name VARCHAR, 
    IN last_name VARCHAR, 
    IN email VARCHAR, 
    IN address VARCHAR, 
    IN address2 VARCHAR, 
    IN district VARCHAR, 
    IN city_name VARCHAR, 
    IN country_name VARCHAR, 
    IN postal_code VARCHAR, 
    IN phone VARCHAR)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    address_id_new integer;
    city_id_new integer;
    country_id_new integer;
    customer_id_new integer;
BEGIN
    -- Inserta la ciudad del cliente si no existe
    SELECT INTO city_id_new city_id FROM public.city WHERE city = city_name;
    IF NOT FOUND THEN
        INSERT INTO public.city (city, country_id)
        VALUES (city_name, (SELECT country_id FROM public.country WHERE country = country_name))
        RETURNING city_id INTO city_id_new;
    END IF;

    -- Inserta el país del cliente si no existe
    SELECT INTO country_id_new country_id FROM public.country WHERE country = country_name;
    IF NOT FOUND THEN
        INSERT INTO public.country (country)
        VALUES (country_name)
        RETURNING country_id INTO country_id_new;
    END IF;

    -- Inserta la dirección del cliente
    INSERT INTO public.address (address, address2, district, city_id, postal_code, phone)
    VALUES (address, address2, district, city_id_new, postal_code, phone)
    RETURNING address_id INTO address_id_new;

    -- Inserta el cliente
    INSERT INTO public.customer (store_id, first_name, last_name, email, address_id)
    VALUES (store_id, first_name, last_name, email, address_id_new)
    RETURNING customer_id INTO customer_id_new;

    -- Actualiza el registro de cliente con el último ID de la ciudad y el país
    UPDATE public.customer SET active = 1, last_update = now(), address_id = address_id_new WHERE customer_id = customer_id_new;
END;
$BODY$;


-- Ejemplo de uso
CALL insert_customer(1, 'John', 'Doe', 'johndoe@example.com', '123 Main St', NULL, 'District 1', 'Almirante Brown', 'Argentina', '12345', '555-1234');
SELECT * FROM customer WHERE first_name = 'John'

/*
Procedimiento: register_rental

Parametros:

rental_date: una marca de tiempo que indica la fecha en que se realizó la renta.
inventory_id: un entero que representa el ID del inventario que se alquiló.
customer_id: un entero que representa el ID del cliente que alquiló el inventario.
staff_id: un entero que representa el ID del personal que procesó la renta.

Descripcion: 
La funcion insertar una nueva renta en la tabla rental. 
*/
CREATE OR REPLACE FUNCTION register_rental(
    rental_date timestamp,
    inventory_id integer,
    customer_id integer,
    staff_id integer
)
RETURNS integer AS $$
DECLARE
    new_rental_id integer;
BEGIN
	-- inserta una nueva fila en la tabla rental 
    INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id)
    VALUES (rental_date, inventory_id, customer_id, staff_id)
    RETURNING rental_id INTO new_rental_id;
	
	-- devuelve un entero que representa el ID de la nueva renta insertada en la tabla rental.
    RETURN new_rental_id;
END;
$$ LANGUAGE plpgsql;

-- Ejemplo de uso
SELECT register_rental('2023-04-28 10:00:00', 1234, 567, 1);
SELECT * FROM rental WHERE rental_id = 16051

/*
Función: register_return

Parametros: 
p_rental_id: Es el ID del alquiler de la película que se va a devolver

Descripcion: 
Registrar una devolución y verificar si está atrasada. Si está atrasada, 
se agregará un registro de pago con la tarifa de atraso correspondiente en la tabla de pago. 
*/

-- DROP FUNCTION IF EXISTS register_return(integer);

CREATE OR REPLACE FUNCTION register_return(
    p_rental_id integer -- ID de alquiler de la película a devolver
    ) 
    RETURNS numeric(5,2) -- Devuelve el monto a cobrar por días atrasados en la devolución
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_rental_date timestamp; -- Fecha de alquiler
    v_return_date timestamp; -- Fecha de devolución
    v_rental_rate numeric(4,2); -- Tasa de alquiler por día
    v_rental_days integer; -- Número de días de alquiler
    v_days_late integer; -- Número de días atrasados en la devolución
    v_amount numeric(5,2); -- Monto total a cobrar
    v_film_id integer; -- ID de la película
BEGIN
    -- Obtener información del alquiler
    SELECT rental_date, return_date, inventory_id
    INTO v_rental_date, v_return_date, v_film_id
    FROM rental
    WHERE rental_id = p_rental_id;
    
    -- Verificar si la película ya fue devuelta
    IF v_return_date IS NOT NULL THEN
        RAISE EXCEPTION 'La película ya ha sido devuelta';
    END IF;
    
    -- Actualizar la fecha de devolución del alquiler
    UPDATE rental
    SET return_date = CURRENT_TIMESTAMP
    WHERE rental_id = p_rental_id;
    
    -- Devolver la película al inventario
    UPDATE inventory
    SET last_update = CURRENT_TIMESTAMP
    WHERE inventory_id = v_film_id;
    
    -- Calcular la cantidad de días de alquiler y la cantidad de días de atraso
    SELECT EXTRACT(DAYS FROM v_return_date - v_rental_date) AS rental_days,
           CASE 
                WHEN v_return_date > (v_rental_date + INTERVAL '3 days') THEN
                    EXTRACT(DAYS FROM v_return_date - (v_rental_date + INTERVAL '3 days'))
                ELSE
                    0
            END AS days_late,
           rental_rate
    INTO v_rental_days, v_days_late, v_rental_rate
    FROM film
    WHERE film_id = v_film_id;
    
    -- Calcular el monto a cobrar por días de atraso
    v_amount := v_days_late * v_rental_rate;
    
    -- Devolver el monto total a cobrar
    RETURN v_amount;
END;
$BODY$;

-- Ejemplo de uso
SELECT register_return(16051);

/*
Función: search_movie

Descripción:
Esta función recibe como parámetro el título de una película y busca en la tabla de películas
todas aquellas que contengan ese título. La función devuelve un conjunto de resultados con 
todas las películas que coincidan con el título proporcionado.

Parámetros:
	title: título de la película a buscar.

Salida: 
	Devuelve un conjunto de resultados con las películas que coincidan con el título.
*/
CREATE OR REPLACE FUNCTION search_movie(p_title VARCHAR)
RETURNS TABLE (film_id INT, title VARCHAR, description TEXT, release_year YEAR)
AS $$
BEGIN
    -- Busca las películas que coincidan con el título.
    RETURN QUERY
    SELECT public.film.film_id, public.film.title, public.film.description, public.film.release_year
    FROM public.film
    WHERE public.film.title ILIKE '%' || p_title || '%';
END;
$$ LANGUAGE plpgsql;

-- Ejemplo de uso
SELECT * FROM search_movie('Action');


-- Crea el rol EMP
CREATE ROLE EMP;
GRANT EXECUTE ON FUNCTION register_rental(timestamp, INT, INT, INT, OUT INT) TO EMP;
GRANT EXECUTE ON FUNCTION register_return(INT, OUT INT) TO EMP;
GRANT EXECUTE ON FUNCTION search_movie(VARCHAR) TO EMP;

-- Crea el rol ADMIN
CREATE ROLE ADMIN;
GRANT EMP TO ADMIN;
GRANT EXECUTE ON PROCEDURE insert_customer(INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO ADMIN;

-- Crear el usuario 'video' sin inicio de sesión
CREATE USER video NOLOGIN;
-- Asignarle permisos de dueño a todas las tablas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO video;
-- Asignarle permisos de dueño a todos los procedimientos almacenados
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO video;

-- Crear el usuario 'empleado1' y asignarle el rol 'EMP'
CREATE USER empleado1;
GRANT EMP TO empleado1;

-- Crear el usuario 'administrador1' y asignarle el rol 'ADMIN'
CREATE USER administrador1;
GRANT ADMIN TO administrador1;

GRANT EXECUTE ON PROCEDURE insert_customer TO video;
GRANT EXECUTE ON FUNCTION register_rental TO video;
GRANT EXECUTE ON FUNCTION register_return TO video;
GRANT EXECUTE ON FUNCTION search_movie TO video;
