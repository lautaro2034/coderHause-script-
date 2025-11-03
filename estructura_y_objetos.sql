
-- estructura_y_objetos.sql
-- Script de creación de tablas (basado en la entrega 1), vistas, funciones, stored procedures y triggers
-- MySQL / MariaDB compatible. Ajustar charset y engine según su servidor.

DROP DATABASE IF EXISTS alquiler_canchas;
CREATE DATABASE alquiler_canchas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE alquiler_canchas;

-- TABLAS
CREATE TABLE usuario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(150) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  nombre VARCHAR(100),
  apellido VARCHAR(100),
  tipo_usuario ENUM('ADMIN','RECEPCIONISTA','ENCARGADO') NOT NULL
);

CREATE TABLE cliente (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100),
  dni VARCHAR(20) UNIQUE,
  telefono VARCHAR(50),
  email VARCHAR(150)
);

CREATE TABLE cancha (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  tipo ENUM('FUTBOL5','FUTBOL7','PADEL','TENIS') NOT NULL,
  precio_hora DECIMAL(10,2) NOT NULL
);

CREATE TABLE horario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  hora_inicio TIME NOT NULL,
  hora_fin TIME NOT NULL
);

CREATE TABLE reserva (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT,
  cancha_id INT,
  horario_id INT,
  fecha DATE NOT NULL,
  usuario_id INT,
  estado ENUM('PENDIENTE','CONFIRMADA','CANCELADA') DEFAULT 'PENDIENTE',
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE SET NULL,
  FOREIGN KEY (cancha_id) REFERENCES cancha(id) ON DELETE CASCADE,
  FOREIGN KEY (horario_id) REFERENCES horario(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE SET NULL
);

CREATE TABLE pago (
  id INT AUTO_INCREMENT PRIMARY KEY,
  reserva_id INT,
  monto DECIMAL(10,2),
  fecha_pago DATETIME DEFAULT CURRENT_TIMESTAMP,
  metodo ENUM('EFECTIVO','DEBITO','CREDITO','TRANSFERENCIA'),
  comprobante VARCHAR(255),
  FOREIGN KEY (reserva_id) REFERENCES reserva(id) ON DELETE CASCADE
);

-- Índices sugeridos
CREATE INDEX idx_reserva_fecha ON reserva(fecha);
CREATE INDEX idx_cliente_dni ON cliente(dni);
CREATE INDEX idx_reserva_cancha_fecha ON reserva(cancha_id, fecha, horario_id);

-- VISTAS
DROP VIEW IF EXISTS vista_reservas_detalle;
CREATE VIEW vista_reservas_detalle AS
SELECT r.id AS reserva_id,
       r.fecha,
       h.hora_inicio,
       h.hora_fin,
       c.id AS cancha_id,
       c.nombre AS cancha_nombre,
       c.tipo AS cancha_tipo,
       CONCAT(cl.nombre, ' ', cl.apellido) AS cliente,
       r.estado,
       r.creado_en
FROM reserva r
JOIN horario h ON r.horario_id = h.id
JOIN cancha c ON r.cancha_id = c.id
LEFT JOIN cliente cl ON r.cliente_id = cl.id;

-- Vista de disponibilidad por cancha y fecha (muestra los horarios ocupados)
DROP VIEW IF EXISTS vista_disponibilidad_cancha;
CREATE VIEW vista_disponibilidad_cancha AS
SELECT c.id AS cancha_id,
       c.nombre AS cancha_nombre,
       r.fecha,
       h.id AS horario_id,
       h.hora_inicio,
       h.hora_fin,
       r.estado,
       r.id AS reserva_id
FROM cancha c
LEFT JOIN reserva r ON r.cancha_id = c.id
LEFT JOIN horario h ON h.id = r.horario_id;

-- FUNCIONES
DROP FUNCTION IF EXISTS fn_cancha_esta_ocupada;
DELIMITER $$
CREATE FUNCTION fn_cancha_esta_ocupada(p_cancha_id INT, p_fecha DATE, p_horario_id INT)
RETURNS TINYINT
DETERMINISTIC
BEGIN
  DECLARE cnt INT;
  SELECT COUNT(*) INTO cnt
  FROM reserva
  WHERE cancha_id = p_cancha_id
    AND fecha = p_fecha
    AND horario_id = p_horario_id
    AND estado <> 'CANCELADA';
  IF cnt > 0 THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
END$$
DELIMITER ;

DROP FUNCTION IF EXISTS fn_total_recaudado_por_dia;
DELIMITER $$
CREATE FUNCTION fn_total_recaudado_por_dia(p_fecha DATE)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
  DECLARE total DECIMAL(12,2) DEFAULT 0;
  SELECT IFNULL(SUM(monto),0) INTO total
  FROM pago
  WHERE DATE(fecha_pago) = p_fecha;
  RETURN total;
END$$
DELIMITER ;

-- STORED PROCEDURES
DROP PROCEDURE IF EXISTS sp_crear_reserva;
DELIMITER $$
CREATE PROCEDURE sp_crear_reserva(
  IN p_cliente_id INT,
  IN p_cancha_id INT,
  IN p_horario_id INT,
  IN p_fecha DATE,
  IN p_usuario_id INT,
  OUT p_reserva_id INT
)
BEGIN
  -- Verificar disponibilidad
  IF fn_cancha_esta_ocupada(p_cancha_id, p_fecha, p_horario_id) = 1 THEN
    SET p_reserva_id = NULL;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cancha ya se encuentra reservada para ese horario.';
  ELSE
    INSERT INTO reserva (cliente_id, cancha_id, horario_id, fecha, usuario_id, estado)
    VALUES (p_cliente_id, p_cancha_id, p_horario_id, p_fecha, p_usuario_id, 'PENDIENTE');
    SET p_reserva_id = LAST_INSERT_ID();
  END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_confirmar_reserva_con_pago;
DELIMITER $$
CREATE PROCEDURE sp_confirmar_reserva_con_pago(
  IN p_reserva_id INT,
  IN p_monto DECIMAL(10,2),
  IN p_metodo ENUM('EFECTIVO','DEBITO','CREDITO','TRANSFERENCIA'),
  IN p_comprobante VARCHAR(255)
)
BEGIN
  -- Insertar pago y actualizar estado de reserva
  INSERT INTO pago (reserva_id, monto, metodo, comprobante)
  VALUES (p_reserva_id, p_monto, p_metodo, p_comprobante);
  UPDATE reserva SET estado = 'CONFIRMADA' WHERE id = p_reserva_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_cancelar_reserva;
DELIMITER $$
CREATE PROCEDURE sp_cancelar_reserva(
  IN p_reserva_id INT,
  IN p_motivo VARCHAR(255)
)
BEGIN
  -- Actualiza estado y registra un log (si hubiese una tabla de logs se usaría aquí)
  UPDATE reserva SET estado = 'CANCELADA' WHERE id = p_reserva_id;
  -- (Opcional) devolver pago: lógica dependiente de políticas
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_reporte_ocupacion;
DELIMITER $$
CREATE PROCEDURE sp_reporte_ocupacion(
  IN p_fecha_inicio DATE,
  IN p_fecha_fin DATE
)
BEGIN
  SELECT c.id AS cancha_id, c.nombre AS cancha, c.tipo,
         r.fecha, h.hora_inicio, h.hora_fin, COUNT(r.id) AS reservas
  FROM cancha c
  LEFT JOIN reserva r ON r.cancha_id = c.id AND r.fecha BETWEEN p_fecha_inicio AND p_fecha_fin AND r.estado <> 'CANCELADA'
  LEFT JOIN horario h ON h.id = r.horario_id
  GROUP BY c.id, c.nombre, c.tipo, r.fecha, h.hora_inicio, h.hora_fin
  ORDER BY c.id, r.fecha, h.hora_inicio;
END$$
DELIMITER ;

-- TRIGGERS
DROP TRIGGER IF EXISTS trg_pago_confirma_reserva;
DELIMITER $$
CREATE TRIGGER trg_pago_confirma_reserva
AFTER INSERT ON pago
FOR EACH ROW
BEGIN
  -- Cuando se registra un pago, confirmar la reserva asociada
  UPDATE reserva SET estado = 'CONFIRMADA' WHERE id = NEW.reserva_id;
END$$
DELIMITER ;

-- Trigger para prevenir doble reserva (simple verificación AFTER INSERT que hace rollback si detecta conflicto)
-- NOTA: MySQL no permite ROLLBACK en triggers; por eso usamos SIGNAL para abortar la transacción.
DROP TRIGGER IF EXISTS trg_prevenir_doble_reserva;
DELIMITER $$
CREATE TRIGGER trg_prevenir_doble_reserva
BEFORE INSERT ON reserva
FOR EACH ROW
BEGIN
  DECLARE cnt INT;
  SELECT COUNT(*) INTO cnt FROM reserva
  WHERE cancha_id = NEW.cancha_id
    AND fecha = NEW.fecha
    AND horario_id = NEW.horario_id
    AND estado <> 'CANCELADA';
  IF cnt > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conflicto: horario ya reservado para esa cancha.';
  END IF;
END$$
DELIMITER ;

-- Fin del script estructura_y_objetos.sql
