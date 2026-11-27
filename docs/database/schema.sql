-- Қалалық жол кептелістерін талдау, модельдеу және болжау ақпараттық жүйесі
-- Дерекқор схемасы (PostgreSQL). ERD: docs/database/erd.png
-- DFD қоймалары: D1 traffic_measurements, D2 forecasts, D3 alerts, D4 users

DROP TABLE IF EXISTS alerts;
DROP TABLE IF EXISTS forecast_segments;
DROP TABLE IF EXISTS forecasts;
DROP TABLE IF EXISTS traffic_measurements;
DROP TABLE IF EXISTS road_segments;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS roles;

-- 1. Рөлдер (README-дегі пайдаланушылар)
CREATE TABLE roles (
    role_id   INTEGER PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

-- 2. Пайдаланушылар (DFD: D4)
CREATE TABLE users (
    user_id   INTEGER PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email     VARCHAR(100) NOT NULL UNIQUE,
    role_id   INTEGER NOT NULL,
    FOREIGN KEY (role_id) REFERENCES roles (role_id)
);

-- 3. Жол учаскелері
CREATE TABLE road_segments (
    segment_id   INTEGER PRIMARY KEY,
    segment_name VARCHAR(100) NOT NULL,
    district     VARCHAR(50)  NOT NULL
);

-- 4. Трафик өлшемдері (DFD: D1)
CREATE TABLE traffic_measurements (
    measurement_id INTEGER PRIMARY KEY,
    segment_id     INTEGER NOT NULL,
    measured_at    TIMESTAMP NOT NULL,
    avg_speed      DECIMAL(5,1) NOT NULL,
    vehicle_count  INTEGER NOT NULL,
    FOREIGN KEY (segment_id) REFERENCES road_segments (segment_id)
);

-- 5. Болжамдар (DFD: D2)
CREATE TABLE forecasts (
    forecast_id  INTEGER PRIMARY KEY,
    user_id      INTEGER NOT NULL,
    period_start TIMESTAMP NOT NULL,
    period_end   TIMESTAMP NOT NULL,
    created_at   TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (user_id)
);

-- 6. Болжам нәтижесі учаскелер бойынша (аралық кесте: forecasts M:N road_segments)
CREATE TABLE forecast_segments (
    forecast_id      INTEGER NOT NULL,
    segment_id       INTEGER NOT NULL,
    congestion_level INTEGER NOT NULL CHECK (congestion_level BETWEEN 1 AND 5),
    predicted_speed  DECIMAL(5,1) NOT NULL,
    PRIMARY KEY (forecast_id, segment_id),
    FOREIGN KEY (forecast_id) REFERENCES forecasts (forecast_id),
    FOREIGN KEY (segment_id)  REFERENCES road_segments (segment_id)
);

-- 7. Ескертулер (DFD: D3)
CREATE TABLE alerts (
    alert_id    INTEGER PRIMARY KEY,
    forecast_id INTEGER NOT NULL,
    segment_id  INTEGER NOT NULL,
    created_at  TIMESTAMP NOT NULL,
    message     VARCHAR(200) NOT NULL,
    FOREIGN KEY (forecast_id) REFERENCES forecasts (forecast_id),
    FOREIGN KEY (segment_id)  REFERENCES road_segments (segment_id)
);

-- ---------------------------------------------------------------
-- Тестілік деректер
-- ---------------------------------------------------------------
INSERT INTO roles (role_id, role_name) VALUES
    (1, 'Трафик аналитигі'),
    (2, 'Диспетчер'),
    (3, 'Қала жоспарлаушысы'),
    (4, 'Әкімші');

INSERT INTO users (user_id, full_name, email, role_id) VALUES
    (1, 'Айдар Серіков',     'aidar@traffic.kz',  1),
    (2, 'Мадина Ахметова',   'madina@traffic.kz', 1),
    (3, 'Ержан Нұрланов',    'erzhan@traffic.kz', 2),
    (4, 'Гүлнар Омарова',    'gulnar@traffic.kz', 3),
    (5, 'Дәурен Қасымов',    'dauren@traffic.kz', 4);

INSERT INTO road_segments (segment_id, segment_name, district) VALUES
    (1, 'Әл-Фараби даңғылы', 'Бостандық'),
    (2, 'Абай даңғылы',      'Алмалы'),
    (3, 'Райымбек даңғылы',  'Алмалы'),
    (4, 'Сәтбаев көшесі',    'Бостандық'),
    (5, 'Төле би көшесі',    'Медеу');

INSERT INTO traffic_measurements (measurement_id, segment_id, measured_at, avg_speed, vehicle_count) VALUES
    (1, 1, '2026-11-20 08:00:00', 18.5, 1250),
    (2, 1, '2026-11-20 18:00:00', 14.2, 1480),
    (3, 2, '2026-11-20 08:00:00', 25.0,  900),
    (4, 3, '2026-11-20 08:00:00', 31.7,  720),
    (5, 4, '2026-11-20 08:00:00', 22.3, 1010);

INSERT INTO forecasts (forecast_id, user_id, period_start, period_end, created_at) VALUES
    (1, 1, '2026-11-23 07:00:00', '2026-11-23 10:00:00', '2026-11-22 20:15:00'),
    (2, 1, '2026-11-23 17:00:00', '2026-11-23 20:00:00', '2026-11-22 20:20:00'),
    (3, 2, '2026-11-24 07:00:00', '2026-11-24 10:00:00', '2026-11-23 19:40:00'),
    (4, 2, '2026-11-24 17:00:00', '2026-11-24 20:00:00', '2026-11-23 19:45:00');

INSERT INTO forecast_segments (forecast_id, segment_id, congestion_level, predicted_speed) VALUES
    (1, 1, 4, 15.0),
    (1, 2, 3, 24.5),
    (2, 1, 5, 11.8),
    (3, 4, 3, 21.0),
    (4, 3, 2, 30.2);

INSERT INTO alerts (alert_id, forecast_id, segment_id, created_at, message) VALUES
    (1, 1, 1, '2026-11-22 20:16:00', 'Әл-Фараби даңғылында кептеліс деңгейі шектен асты'),
    (2, 2, 1, '2026-11-22 20:21:00', 'Әл-Фараби даңғылында кептеліс деңгейі өте жоғары'),
    (3, 3, 4, '2026-11-23 19:41:00', 'Сәтбаев көшесінде кептеліс күтіледі');

-- ---------------------------------------------------------------
-- Сұраныстар
-- ---------------------------------------------------------------

-- Сұраныс 1: 5 кестені JOIN арқылы біріктіру
-- Кім қай учаске үшін болжам құрды және кептеліс деңгейі қандай
SELECT u.full_name        AS analyst,
       r.role_name,
       f.forecast_id,
       rs.segment_name,
       fs.congestion_level,
       fs.predicted_speed
FROM forecasts f
JOIN users u              ON f.user_id = u.user_id
JOIN roles r              ON u.role_id = r.role_id
JOIN forecast_segments fs ON fs.forecast_id = f.forecast_id
JOIN road_segments rs     ON rs.segment_id = fs.segment_id
ORDER BY f.forecast_id, rs.segment_name;

-- Сұраныс 2: GROUP BY
-- Аудандар бойынша өлшемдер саны, орташа жылдамдық және көлік саны
SELECT rs.district,
       COUNT(tm.measurement_id)    AS measurement_count,
       ROUND(AVG(tm.avg_speed), 1) AS avg_speed,
       SUM(tm.vehicle_count)       AS total_vehicles
FROM road_segments rs
JOIN traffic_measurements tm ON tm.segment_id = rs.segment_id
GROUP BY rs.district
ORDER BY avg_speed;
