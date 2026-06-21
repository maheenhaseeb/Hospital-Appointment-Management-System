from flask import Flask, render_template, request, redirect, url_for, flash, session
import psycopg2
from psycopg2 import extras

app = Flask(__name__)
app.secret_key = "hospital_secret_key"

def get_db_connection():
    try:
        return psycopg2.connect(
            host="localhost", database="hospital_db",
            user="postgres", password="maheen19", port="5432"
        )
    except Exception as e:
        print(f"Database Connection Error: {e}")
        return None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['POST'])
def login():
    email_in = request.form['email'].strip()
    pw_in = request.form['password']
    
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=extras.DictCursor)
    
    # 1. Check Patients
    cur.execute('SELECT * FROM Patients WHERE email = %s AND patient_password = %s', (email_in, pw_in))
    user = cur.fetchone()
    if user:
        session.update({'user_id': user['patient_id'], 'user_name': user['patient_name'], 'role': 'patient'})
        return redirect(url_for('index'))

    # 2. Check Doctors
    cur.execute('SELECT * FROM Doctors WHERE email = %s AND doctor_password = %s', (email_in, pw_in))
    doctor = cur.fetchone()
    if doctor:
        session.update({'user_id': doctor['doc_id'], 'user_name': doctor['doctor_name'], 'role': 'doctor'})
        return redirect(url_for('index'))

    # 3. Check Admins
    cur.execute('SELECT * FROM Admins WHERE email = %s AND admin_password = %s', (email_in, pw_in))
    admin = cur.fetchone()
    if admin:
        session.update({'user_id': admin['admin_id'], 'user_name': admin['username'], 'role': 'admin'})
        return redirect(url_for('index'))

    flash("Invalid Credentials")
    return redirect(url_for('index'))

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form.get('name')
        email = request.form.get('email')
        pw = request.form.get('password')
        phone = request.form.get('contact')
        role = request.form.get('role')
        
        conn = get_db_connection()
        cur = conn.cursor()
        try:
            if role == 'admin':
                cur.execute('INSERT INTO Admins (username, email, admin_password,contact) VALUES (%s, %s, %s,%s)', (name, email, pw, phone))
            elif role == 'doctor':
                spec = request.form.get('specialization')
                cur.execute('INSERT INTO Doctors (doctor_name, email,contact, doctor_password, specialization, dept_id) VALUES (%s, %s, %s, %s,%s, 4)', (name, email,phone, pw, spec))
            else:
                cur.execute('INSERT INTO Patients (patient_name, email, patient_password,contact, role) VALUES (%s, %s, %s, %s,%s)', (name, email, pw,phone, 'patient'))
            conn.commit()
            flash("Account Created!")
        except Exception as e:
            conn.rollback()
            flash(f"Error: {e}")
        finally:
            cur.close()
            conn.close()
        return redirect(url_for('index'))
    return render_template('register.html')

@app.route('/book', methods=['GET', 'POST'])
def book():
    if 'user_id' not in session: return redirect(url_for('index'))
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=extras.DictCursor)
    if request.method == 'POST':
        cur.execute('INSERT INTO Appointments (patient_id, doc_id, app_date) VALUES (%s, %s, %s)', 
                    (session['user_id'], request.form.get('doctor'), request.form.get('app_date')))
        conn.commit()
        return redirect(url_for('history'))
    cur.execute('SELECT doc_id, doctor_name FROM Doctors')
    doctors = cur.fetchall()
    return render_template('booking.html', doctors=doctors)

@app.route('/history')
def history():
    if 'user_id' not in session: return redirect(url_for('index'))
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=extras.DictCursor)
    role = session['role']
    name = session['user_name']
    
    if role == 'admin':
        cur.execute('SELECT * FROM patient_appointment_history')
    elif role == 'doctor':
        cur.execute('SELECT * FROM patient_appointment_history WHERE doc_name = %s', (name,))
    else:
        cur.execute('SELECT * FROM patient_appointment_history WHERE pat_name = %s', (name,))
    
    apps = cur.fetchall()
    return render_template('history.html', appointments=apps)

@app.route('/complete_appointment/<int:app_id>')
def complete_appointment(app_id):
    if session.get('role') == 'admin':
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE Appointments SET status = 'Completed' WHERE app_id = %s", (app_id,))
        conn.commit()
        cur.close()
        conn.close()
        flash(f"Appointment #{app_id} marked as Completed.")
    return redirect(url_for('history'))

@app.route('/pay_bill/<int:app_id>')
def pay_bill(app_id):
    if session.get('role') == 'admin':
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE Bills SET payment_status = 'Paid' WHERE app_id = %s", (app_id,))
        conn.commit()
        cur.close()
        conn.close()
        flash(f"Bill for Appointment #{app_id} marked as Paid.")
    return redirect(url_for('history'))

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True)