
DROP VIEW IF EXISTS patient_appointment_history;
DROP TABLE IF EXISTS AppointmentLogs, Bills, Medical_Records, Appointments, Patients, Doctors, Departments, Admins CASCADE;

-- 1: Departments
CREATE TABLE Departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL
);

-- 2: Doctors
CREATE TABLE Doctors (
    doc_id SERIAL PRIMARY KEY,
    doctor_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
	contact VARCHAR(11) NOT NULL CHECK (length(contact) = 11),
    doctor_password VARCHAR(255) NOT NULL,
    specialization VARCHAR(100),
    dept_id INT REFERENCES Departments(dept_id) ON DELETE SET NULL
);

-- 3: Patients
CREATE TABLE Patients (
    patient_id SERIAL PRIMARY KEY,
    patient_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    patient_password VARCHAR(255) NOT NULL,
    contact VARCHAR(11) NOT NULL CHECK (length(contact) = 11),
    role VARCHAR(20) DEFAULT 'patient'
);

-- 4: Admins
CREATE TABLE Admins (
    admin_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    admin_password VARCHAR(255) NOT NULL,
	contact VARCHAR(11) NOT NULL CHECK (length(contact) = 11)
);

-- 5: Appointments
CREATE TABLE Appointments (
    app_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES Patients(patient_id) ON DELETE CASCADE,
    doc_id INT REFERENCES Doctors(doc_id) ON DELETE CASCADE,
    app_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'Scheduled'
);

-- 6: Medical Records
CREATE TABLE Medical_Records (
    record_id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES Patients(patient_id) ON DELETE CASCADE,
    doc_id INT REFERENCES Doctors(doc_id) ON DELETE CASCADE,
    diagnosis TEXT,
    treatment TEXT,
    record_date DATE DEFAULT CURRENT_DATE
);

-- 7: AppointmentLogs
CREATE TABLE AppointmentLogs (
    log_id SERIAL PRIMARY KEY,
    app_id INT,
    action_performed VARCHAR(100),
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8: Bills
CREATE TABLE Bills (
    bill_id SERIAL PRIMARY KEY,
    app_id INT REFERENCES Appointments(app_id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) DEFAULT 1500.00,
    payment_status VARCHAR(20) DEFAULT 'Unpaid'
);

ALTER TABLE Bills ADD COLUMN processed_by INT REFERENCES Admins(admin_id);

-- View
CREATE OR REPLACE VIEW patient_appointment_history AS
SELECT 
    a.app_id, p.patient_name AS pat_name, d.doctor_name AS doc_name,
    a.app_date, a.status, COALESCE(b.payment_status, 'Unpaid') AS payment_status
FROM Appointments a
JOIN Patients p ON a.patient_id = p.patient_id
LEFT JOIN Doctors d ON a.doc_id = d.doc_id
LEFT JOIN Bills b ON a.app_id = b.app_id;

-- Trigger
CREATE OR REPLACE FUNCTION log_new_appointment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO AppointmentLogs(app_id, action_performed)
    VALUES (NEW.app_id, 'New appointment booked for patient ID: ' || NEW.patient_id);
    INSERT INTO Bills(app_id, amount, payment_status)
    VALUES (NEW.app_id, 1500.00, 'Unpaid');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_appointment_insert
AFTER INSERT ON Appointments
FOR EACH ROW EXECUTE FUNCTION log_new_appointment();

-- Populate data
INSERT INTO Departments (dept_name) VALUES 
('Cardiology'), 
('Neurology'), 
('Psychiatrist'),
('General Physician'),
('Nephrologist'),
('Gastroenterologist'),
('Infectious Diseases'),
('Neurosurgeon'),
('Dermatologist'),
('Pediatrics');

-- Sample Admin
INSERT INTO Admins (username, email, admin_password,contact) VALUES 
('Abdullah Sheikh', 'abd@gmail.com', 'abd1234','28374650192'),
('Rehan Asghar', 'rehan@gmail.com', 'rehan1234','44392817465'),
('Talha Ahmed', 'talha@gmail.com', 'talha1234','88273645019');

-- Sample Doctor
INSERT INTO Doctors (doctor_name, email,contact,doctor_password, specialization, dept_id) VALUES
('Dr. Safa Rehman', 'safa@gmail.com','48291057362', 'safa123', 'Cardiologist', 1),
('Dr. Maheen Haseeb', 'maheen@gmail.com','77301495821', 'maheen123', 'Nephrologist', 5),
('Dr. Mohammad Nafees', 'nafees@gmail.com','10928374655', 'nafees123', 'Psychiatrist', 3),
('Dr. Suleiman Malik', 'suleiman@gmail.com','65412908374', 'suleiman123', 'Infectious Diseases',7),
('Dr. Khadijah Rasheed ', 'khadijah@gmail.com','92837461502', 'khadijah123', 'Neurosurgeon',8),
('Dr. Humna Zafar', 'humna@gmail.com','65748392019','humna123','Gastroenterologist',6),
('Dr. Mahnoor Mansoor', 'mahnoor@gmail.com','56473829104', 'mahnoor123', 'General Physician',4),
('Dr. Maria Sheikh', 'maria@gmail.com','56473829104', 'maria123', 'Dermatologist',9);

-- Sample Patient
INSERT INTO Patients (patient_name, email, patient_password, contact) VALUES 
('Safwan Alvi', 'safwan@gmail.com', 'murakami29', '03001234567'),
('Amna Rizvi', 'amnarizvi@example.com', 'habibiuni', '03001226978'),
('Nabiha Ashfaq', 'nabihaashfaq@example.com', 'polisci23', '03007784967'),
('Laksh Kumar', 'laksh@example.com', 'laksh18', '03002188840'),
('Haider Ali', 'haider@example.com', 'giki28', '03001918781');

-- populating bills
INSERT INTO Bills (app_id, amount, payment_status)
SELECT app_id, 1500.00, 'Unpaid'
FROM Appointments
WHERE app_id NOT IN (SELECT app_id FROM Bills);


UPDATE Bills SET payment_status = 'Paid' WHERE app_id = (SELECT MIN(app_id) FROM Appointments);

-- medical records population
INSERT INTO Medical_Records (patient_id, doc_id, diagnosis, treatment) VALUES 
(3, 4, 'Seasonal Flu', 'Paracetamol'),
(2, 1, 'Cholesterol', 'Lesser salt intake'),
(4, 6, 'Ulcer', 'Biopsy');


--subqueries
SELECT doctor_name, specialization
FROM Doctors 
WHERE doc_id IN (
    SELECT doc_id 
    FROM Appointments 
    GROUP BY doc_id 
    HAVING COUNT(*) > 2
);

--update
UPDATE Patients
SET contact = '03332199840'
WHERE patient_id = 2;

--delete
--DELETE FROM Patients
--WHERE patient_id = 5;

--TRUNCATE Appointments CASCADE;