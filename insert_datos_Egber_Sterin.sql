-- ===========================================
-- ARCHIVO: insert_datos.sql
-- PROYECTO: Sistema de Gestión de Alquiler de Canchas
-- AUTOR: Lautaro Egber Sterin
-- ===========================================

USE alquiler_canchas;

-- ===========================================
-- INSERTS DE TABLAS BÁSICAS
-- ===========================================

-- USUARIOS
INSERT INTO usuario (email, password, nombre, apellido, tipo_usuario) VALUES
('admin@club.com', 'admin123', 'María', 'Lopez', 'ADMIN'),
('recepcion@club.com', 'recep123', 'Juan', 'Pérez', 'RECEPCIONISTA'),
('finanzas@club.com', 'fin123', 'Carla', 'Gómez', 'ENCARGADO');

-- CLIENTES
INSERT INTO cliente (nombre, apellido, dni, telefono, email) VALUES
('Lucas', 'Fernández', '40872123', '1122334455', 'lucasf@gmail.com'),
('Valentina', 'Molina', '39765432', '1167893210', 'valemolina@gmail.com'),
('Martín', 'Pérez', '38111222', '1144556677', 'martinp@gmail.com');

-- CANCHAS
INSERT INTO cancha (nombre, tipo, precio_hora) VALUES
('Cancha 1', 'FUTBOL5', 6000.00),
('Cancha 2', 'FUTBOL7', 8000.00),
('Cancha 3', 'PADEL', 5500.00),
('Cancha 4', 'TENIS', 7000.00);

-- HORARIOS
INSERT INTO horario (hora_inicio, hora_fin) VALUES
('09:00:00', '10:00:00'),
('10:00:00', '11:00:00'),
('11:00:00', '12:00:00'),
('12:00:00', '13:00:00'),
('17:00:00', '18:00:00'),
('18:00:00', '19:00:00'),
('19:00:00', '20:00:00');

-- RESERVAS
INSERT INTO reserva (cliente_id, cancha_id, horario_id, fecha, usuario_id, estado) VALUES
(1, 1, 1, '2025-11-04', 2, 'CONFIRMADA'),
(2, 3, 6, '2025-11-04', 2, 'PENDIENTE'),
(3, 4, 7, '2025-11-05', 1, 'CANCELADA');

-- PAGOS
INSERT INTO pago (reserva_id, monto, fecha_pago, metodo) VALUES
(1, 6000.00, '2025-11-03 18:10:00', 'EFECTIVO');

-- Nueva reserva con pago pendiente
INSERT INTO reserva (cliente_id, cancha_id, horario_id, fecha, usuario_id, estado)
VALUES (2, 2, 5, '2025-11-06', 2, 'PENDIENTE');

-- Pago de esa reserva
INSERT INTO pago (reserva_id, monto, fecha_pago, metodo)
VALUES (4, 8000.00, '2025-11-06 17:15:00', 'TRANSFERENCIA');
