from flask import Flask, jsonify, request, send_from_directory
import os
from datetime import datetime

app = Flask(__name__)
PHOTO_DIR = os.path.join(os.path.dirname(__file__), 'photos')
os.makedirs(PHOTO_DIR, exist_ok=True)

@app.route('/api/take_photo', methods=['POST'])
def take_photo():
    # Platzhalter: Hier Kamera ansteuern (z.B. mit subprocess)
    filename = f"photo_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    filepath = os.path.join(PHOTO_DIR, filename)
    # Beispiel: Dummy-Bild erzeugen
    with open(filepath, 'wb') as f:
        f.write(b'\xff\xd8\xff\xd9')  # Leeres JPEG
    return jsonify({'success': True, 'filename': filename})

@app.route('/api/photos', methods=['GET'])
def list_photos():
    files = [f for f in os.listdir(PHOTO_DIR) if f.endswith('.jpg')]
    return jsonify({'photos': files})

@app.route('/photos/<filename>')
def get_photo(filename):
    return send_from_directory(PHOTO_DIR, filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
