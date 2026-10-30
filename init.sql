-- ProSaha Database Schema v2.0
CREATE DATABASE IF NOT EXISTS prosaha CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE prosaha;

-- Kullanıcılar
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('customer', 'admin') DEFAULT 'customer',
    avatar_color VARCHAR(7) DEFAULT '#4ade80',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sahalar
CREATE TABLE fields (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    capacity INT DEFAULT 10,
    price_per_hour DECIMAL(10,2) DEFAULT 500.00,
    is_active BOOLEAN DEFAULT TRUE,
    image_url VARCHAR(255) NULL,
    homepage_image_url VARCHAR(255) NULL
);

-- Rezervasyonlar
CREATE TABLE reservations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    field_id INT NOT NULL DEFAULT 1,
    date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    duration_hours INT DEFAULT 1,
    total_amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'confirmed', 'cancelled', 'completed') DEFAULT 'confirmed',
    payment_status ENUM('unpaid', 'paid') DEFAULT 'unpaid',
    payment_method VARCHAR(50) DEFAULT 'on_site',
    payment_transaction_id VARCHAR(100),
    iyzico_payment_id VARCHAR(100),
    notes TEXT,
    created_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (field_id) REFERENCES fields(id)
);

-- Varsayılan saha
INSERT INTO fields (name, description, capacity, price_per_hour) VALUES 
('Saha 1 - Olimpik', 'FIFA onaylı 3. nesil sentetik çim, profesyonel aydınlatma', 10, 500.00),
('Saha 2 - Standart', 'Yüksek kalite sentetik çim, gece aydınlatması mevcut', 10, 400.00),
('Tenis Kortu', 'Akrilik zemin, gece aydınlatmalı tenis kortu', 4, 300.00),
('Voleybol Sahası', 'Kapalı salon voleybol sahası', 12, 350.00),
('Basketbol Sahası', 'Tam saha potalı basketbol alanı', 10, 450.00),
('Padel Kortu', 'Cam çevreli, profesyonel padel kortu', 4, 380.00);

