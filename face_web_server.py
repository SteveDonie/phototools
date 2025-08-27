#!/usr/bin/env python3
"""
Face Sorter Web Server
Provides a web interface for sorting unknown faces into training directories
"""

import os
import json
import shutil
import glob
from datetime import datetime
from pathlib import Path
import argparse
from urllib.parse import quote, unquote
import mimetypes

# Simple HTTP server imports
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

class FaceSorterHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, config_file="AlbumSettings.default.txt", **kwargs):
        self.config_file = config_file
        self.config = self.load_config()
        super().__init__(*args, **kwargs)
    
    def load_config(self):
        """Load configuration from Perl config file"""
        config = {
            'FaceTrainingDir': 'faces',
            'UnknownFacesDir': 'faces/Unknown'
        }
        
        try:
            with open(self.config_file, 'r') as f:
                content = f.read()
                # Simple parsing of Perl config format
                lines = content.split('\n')
                for line in lines:
                    line = line.strip()
                    if '=>' in line and not line.startswith('#'):
                        parts = line.split('=>')
                        if len(parts) == 2:
                            key = parts[0].strip()
                            value = parts[1].strip().rstrip(',').strip("'\"")
                            config[key] = value
                            #print(f" config: {key} => {value}")

        except FileNotFoundError:
            print(f"Config file {self.config_file} not found, using defaults")
        
        return config
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        
        if path == '/':
            self.serve_main_page()
        elif path == '/api/faces':
            self.serve_faces_api()
        elif path == '/api/people':
            self.serve_people_api()
        elif path == '/api/stats':
            self.serve_stats_api()
        elif path.startswith('/faces/'):
            self.serve_face_image(path)
        else:
            self.send_error(404)
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            data = json.loads(post_data)
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return
        
        if path == '/api/move-faces':
            self.handle_move_faces(data)
        elif path == '/api/delete-faces':
            self.handle_delete_faces(data)
        elif path == '/api/create-person':
            self.handle_create_person(data)
        elif path == '/api/rename-person':
            self.handle_rename_person(data)
        else:
            self.send_error(404)
    
    def serve_main_page(self):
        """Serve the main HTML page"""
        html = self.get_main_html()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))
    
    def serve_faces_api(self):
        """Serve face data API"""
        unknown_dir = self.config.get('UnknownFacesDir', 'faces/Unknown')
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        
        faces = []
        
        # Get unknown faces
        absolute_path = os.path.abspath(unknown_dir)
        print(f"getting faces in unknown_dir: {absolute_path}")

        if os.path.exists(unknown_dir):
            for ext in ['jpg', 'jpeg', 'png', 'bmp']:
                pattern = os.path.join(unknown_dir, f'*.{ext}')
                faces.extend(glob.glob(pattern, recursive=False))
        
        # Get faces from Person directories
        absolute_path = os.path.abspath(training_dir)
        print(f"getting faces in training_dir: {absolute_path}")
        if os.path.exists(training_dir):
            person_dirs = [d for d in os.listdir(training_dir) 
                          if os.path.isdir(os.path.join(training_dir, d)) and d.startswith('Person')]
            
            for person_dir in person_dirs:
                person_path = os.path.join(training_dir, person_dir)
                for ext in ['jpg', 'jpeg', 'png', 'bmp']:
                    pattern = os.path.join(person_path, f'*.{ext}')
                    person_faces = glob.glob(pattern, recursive=False)
                    faces.extend(person_faces)
        
        # Convert to API format
        face_data = []
        for face_path in faces:
            face_file = os.path.basename(face_path)
            face_dir = os.path.basename(os.path.dirname(face_path))
            
            # Extract source photo name
            source = face_file.split('_face')[0] if '_face' in face_file else 'unknown'
            
            try:
                stat = os.stat(face_path)
                face_data.append({
                    'filename': face_file,
                    'directory': face_dir,
                    'source': source,
                    'size': stat.st_size,
                    'date': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    'path': face_path.replace('\\', '/')
                })
            except OSError:
                continue
        
        # Sort by filename
        face_data.sort(key=lambda x: x['filename'])
        
        self.send_json_response(face_data)
    
    def serve_people_api(self):
        """Serve people directories API"""
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        people = []
        
        print(f"getting people in: {training_dir}")
        if os.path.exists(training_dir):
            for item in os.listdir(training_dir):
                item_path = os.path.join(training_dir, item)
                if os.path.isdir(item_path) and item != 'Unknown':
                    # Count training photos
                    photo_count = 0
                    for ext in ['jpg', 'jpeg', 'png', 'bmp']:
                        pattern = os.path.join(item_path, f'*.{ext}')
                        photo_count += len(glob.glob(pattern))
                    
                    people.append({
                        'name': item,
                        'count': photo_count,
                        'is_person_group': item.startswith('Person')
                    })
        
        # Sort with Person groups first, then alphabetically
        people.sort(key=lambda x: (not x['is_person_group'], x['name']))
        
        self.send_json_response(people)
    
    def serve_stats_api(self):
        """Serve statistics API"""
        unknown_dir = self.config.get('UnknownFacesDir', 'faces/Unknown')
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        print(f"getting stats, with unknown_dir: {unknown_dir}")
        print(f"                   training_dir: {training_dir}")

        stats = {
            'unknown_faces': 0,
            'total_people': 0,
            'person_groups': 0,
            'identified_people': 0,
            'total_training_photos': 0
        }
        
        # Count unknown faces
        if os.path.exists(unknown_dir):
            for ext in ['jpg', 'jpeg', 'png', 'bmp']:
                pattern = os.path.join(unknown_dir, f'*.{ext}')
                stats['unknown_faces'] += len(glob.glob(pattern))
        
        # Count people directories
        if os.path.exists(training_dir):
            for item in os.listdir(training_dir):
                item_path = os.path.join(training_dir, item)
                if os.path.isdir(item_path) and item != 'Unknown':
                    stats['total_people'] += 1
                    
                    if item.startswith('Person'):
                        stats['person_groups'] += 1
                    else:
                        stats['identified_people'] += 1
                    
                    # Count photos in this directory
                    for ext in ['jpg', 'jpeg', 'png', 'bmp']:
                        pattern = os.path.join(item_path, f'*.{ext}')
                        stats['total_training_photos'] += len(glob.glob(pattern))
        
        self.send_json_response(stats)
    
    def serve_face_image(self, path):
        """Serve face images"""
        # Remove leading slash and decode
        file_path = unquote(path[1:])
        
        if not os.path.exists(file_path):
            self.send_error(404, "Image not found")
            return
        
        # Security check - ensure file is in allowed directories
        abs_path = os.path.abspath(file_path)
        training_dir = os.path.abspath(self.config.get('FaceTrainingDir', 'faces'))
        
        if not abs_path.startswith(training_dir):
            self.send_error(403, "Access denied")
            return
        
        try:
            with open(file_path, 'rb') as f:
                content = f.read()
            
            # Determine content type
            content_type, _ = mimetypes.guess_type(file_path)
            if not content_type:
                content_type = 'application/octet-stream'
            
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            
        except IOError:
            self.send_error(500, "Error reading file")
    
    def handle_move_faces(self, data):
        """Handle moving faces to a person directory"""
        faces = data.get('faces', [])
        person = data.get('person', '')
        
        if not faces or not person:
            self.send_error(400, "Missing faces or person")
            return
        
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        unknown_dir = self.config.get('UnknownFacesDir', 'faces/Unknown')
        person_dir = os.path.join(training_dir, person)
        
        # Create person directory if it doesn't exist
        if not os.path.exists(person_dir):
            try:
                os.makedirs(person_dir)
            except OSError as e:
                self.send_error(500, f"Error creating directory: {e}")
                return
        
        moved_faces = []
        errors = []
        
        for face_filename in faces:
            # Try to find the face in unknown directory first
            src_path = os.path.join(unknown_dir, face_filename)
            
            # If not in unknown, look in Person directories
            if not os.path.exists(src_path):
                for item in os.listdir(training_dir):
                    if item.startswith('Person'):
                        potential_path = os.path.join(training_dir, item, face_filename)
                        if os.path.exists(potential_path):
                            src_path = potential_path
                            break
            
            if not os.path.exists(src_path):
                errors.append(f"Face not found: {face_filename}")
                continue
            
            dst_path = os.path.join(person_dir, face_filename)
            
            try:
                shutil.move(src_path, dst_path)
                moved_faces.append(face_filename)
            except OSError as e:
                errors.append(f"Error moving {face_filename}: {e}")
        
        response = {
            'success': True,
            'moved_count': len(moved_faces),
            'moved_faces': moved_faces,
            'errors': errors
        }
        
        self.send_json_response(response)
    
    def handle_delete_faces(self, data):
        """Handle deleting faces"""
        faces = data.get('faces', [])
        
        if not faces:
            self.send_error(400, "No faces specified")
            return
        
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        unknown_dir = self.config.get('UnknownFacesDir', 'faces/Unknown')
        
        deleted_faces = []
        errors = []
        
        for face_filename in faces:
            # Try unknown directory first
            face_path = os.path.join(unknown_dir, face_filename)
            
            # If not in unknown, look in Person directories
            if not os.path.exists(face_path):
                for item in os.listdir(training_dir):
                    if item.startswith('Person'):
                        potential_path = os.path.join(training_dir, item, face_filename)
                        if os.path.exists(potential_path):
                            face_path = potential_path
                            break
            
            if not os.path.exists(face_path):
                errors.append(f"Face not found: {face_filename}")
                continue
            
            try:
                os.unlink(face_path)
                deleted_faces.append(face_filename)
            except OSError as e:
                errors.append(f"Error deleting {face_filename}: {e}")
        
        response = {
            'success': True,
            'deleted_count': len(deleted_faces),
            'deleted_faces': deleted_faces,
            'errors': errors
        }
        
        self.send_json_response(response)
    
    def handle_create_person(self, data):
        """Handle creating a new person directory"""
        person_name = data.get('name', '').strip()
        
        if not person_name:
            self.send_error(400, "Person name required")
            return
        
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        person_dir = os.path.join(training_dir, person_name)
        
        if os.path.exists(person_dir):
            self.send_error(400, "Person directory already exists")
            return
        
        try:
            os.makedirs(person_dir)
            response = {'success': True, 'message': f'Created directory for {person_name}'}
            self.send_json_response(response)
        except OSError as e:
            self.send_error(500, f"Error creating directory: {e}")
    
    def handle_rename_person(self, data):
        """Handle renaming a person directory"""
        old_name = data.get('old_name', '').strip()
        new_name = data.get('new_name', '').strip()
        
        if not old_name or not new_name:
            self.send_error(400, "Both old_name and new_name required")
            return
        
        training_dir = self.config.get('FaceTrainingDir', 'faces')
        old_dir = os.path.join(training_dir, old_name)
        new_dir = os.path.join(training_dir, new_name)
        
        if not os.path.exists(old_dir):
            self.send_error(404, f"Directory {old_name} not found")
            return
        
        if os.path.exists(new_dir):
            self.send_error(400, f"Directory {new_name} already exists")
            return
        
        try:
            shutil.move(old_dir, new_dir)
            response = {'success': True, 'message': f'Renamed {old_name} to {new_name}'}
            self.send_json_response(response)
        except OSError as e:
            self.send_error(500, f"Error renaming directory: {e}")
    
    def send_json_response(self, data):
        """Send a JSON response"""
        response = json.dumps(data, indent=2)
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))
    
    def get_main_html(self):
        """Generate the main HTML page"""
        return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Face Sorter - Visual Interface</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f0f0f0;
        }
        
        .header {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .stats {
            display: flex;
            gap: 20px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        
        .stat-box {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            flex: 1;
            min-width: 150px;
        }
        
        .stat-box h3 {
            margin: 0 0 5px 0;
            font-size: 24px;
            color: #1976d2;
        }
        
        .stat-box p {
            margin: 0;
            color: #666;
            font-size: 14px;
        }
        
        .controls {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .filter-controls {
            display: flex;
            gap: 15px;
            align-items: center;
            margin-bottom: 15px;
            flex-wrap: wrap;
        }
        
        .batch-controls {
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .face-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .face-item {
            position: relative;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .face-item:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        
        .face-item.selected {
            border: 3px solid #2196F3;
            transform: scale(1.02);
        }
        
        .face-item img {
            width: 100%;
            height: 150px;
            object-fit: cover;
            cursor: pointer;
        }
        
        .face-info {
            padding: 10px;
            font-size: 12px;
            color: #666;
            text-align: center;
            word-break: break-all;
        }
        
        .face-directory {
            background: #f8f9fa;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 11px;
            margin-bottom: 5px;
            color: #495057;
        }
        
        .checkbox {
            position: absolute;
            top: 8px;
            right: 8px;
            width: 20px;
            height: 20px;
            cursor: pointer;
            z-index: 10;
        }
        
        .pagination {
            text-align: center;
            margin: 20px 0;
        }
        
        .pagination button {
            padding: 10px 15px;
            margin: 0 5px;
            background: #2196F3;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        
        .pagination button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        
        .pagination button:hover:not(:disabled) {
            background: #1976D2;
        }
        
        .person-directories {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .person-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 10px;
            margin-top: 15px;
        }
        
        .person-item {
            padding: 15px;
            background: #f5f5f5;
            border-radius: 8px;
            cursor: pointer;
            transition: background 0.2s;
            position: relative;
        }
        
        .person-item:hover {
            background: #e0e0e0;
        }
        
        .person-item.selected {
            background: #2196F3;
            color: white;
        }
        
        .person-item.person-group {
            border-left: 4px solid #ff9800;
        }
        
        .person-item.identified {
            border-left: 4px solid #4caf50;
        }
        
        .rename-btn {
            position: absolute;
            top: 5px;
            right: 5px;
            background: #666;
            color: white;
            border: none;
            border-radius: 3px;
            padding: 2px 6px;
            font-size: 10px;
            cursor: pointer;
            opacity: 0.7;
        }
        
        .rename-btn:hover {
            opacity: 1;
            background: #333;
        }
        
        .action-buttons {
            margin-top: 20px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        button {
            padding: 10px 20px;
            background: #2196F3;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        
        button:hover:not(:disabled) {
            background: #1976D2;
        }
        
        button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        
        input[type="text"], select {
            padding: 8px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        
        .success {
            color: #4caf50;
            font-weight: bold;
        }
        
        .error {
            color: #f44336;
            font-weight: bold;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        
        .loading:after {
            content: '';
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.5);
        }
        
        .modal-content {
            background-color: white;
            margin: 15% auto;
            padding: 20px;
            border-radius: 8px;
            width: 300px;
            text-align: center;
        }
        
        .modal input {
            width: 100%;
            margin: 10px 0;
        }
        
        .modal-buttons {
            margin-top: 15px;
        }
        
        .modal-buttons button {
            margin: 0 5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Face Sorter - Visual Interface</h1>
        <p>Sort unknown faces into training directories for face recognition.</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <h3 id="unknown-faces">0</h3>
            <p>Unknown Faces</p>
        </div>
        <div class="stat-box">
            <h3 id="selected-count">0</h3>
            <p>Selected Faces</p>
        </div>
        <div class="stat-box">
            <h3 id="person-groups">0</h3>
            <p>Person Groups</p>
        </div>
        <div class="stat-box">
            <h3 id="identified-people">0</h3>
            <p>Identified People</p>
        </div>
        <div class="stat-box">
            <h3 id="total-training">0</h3>
            <p>Training Photos</p>
        </div>
    </div>
    
    <div class="controls">
        <div class="filter-controls">
            <label>Directory:</label>
            <select id="directory-filter">
                <option value="">All directories</option>
            </select>
            
            <label>Source photo:</label>
            <select id="source-filter">
                <option value="">All photos</option>
            </select>
            
            <label>Sort by:</label>
            <select id="sort-order">
                <option value="directory">Directory</option>
                <option value="name">Filename</option>
                <option value="date">Date Created</option>
                <option value="size">File Size</option>
            </select>
            
            <label>Page size:</label>
            <select id="page-size">
                <option value="50">50 faces</option>
                <option value="100" selected>100 faces</option>
                <option value="200">200 faces</option>
            </select>
        </div>
        
        <div class="batch-controls">
            <button onclick="selectAll()">Select All</button>
            <button onclick="selectNone()">Select None</button>
            <button onclick="deleteSelected()">Delete Selected</button>
            <input type="text" id="new-person-name" placeholder="New person name..." />
            <button onclick="createNewPerson()">Create New Person</button>
        </div>
    </div>
    
    <div class="pagination" id="top-pagination">
        <button onclick="previousPage()" id="prev-btn" disabled>← Previous</button>
        <span id="page-info">Page 1 of 1</span>
        <button onclick="nextPage()" id="next-btn" disabled>Next →</button>
    </div>
    
    <div id="face-grid" class="face-grid">
        <div class="loading">Loading faces...</div>
    </div>
    
    <div class="pagination" id="bottom-pagination">
        <button onclick="previousPage()" disabled>← Previous</button>
        <span>Page 1 of 1</span>
        <button onclick="nextPage()" disabled>Next →</button>
    </div>
    
    <div class="person-directories">
        <h3>People Directories</h3>
        <p>Click on a person to move selected faces to their training directory. Orange border = Person groups (need identification), Green border = Identified people.</p>
        <div id="person-grid" class="person-grid">
            <div class="loading">Loading directories...</div>
        </div>
        
        <div class="action-buttons">
            <button onclick="moveToSelected()" id="move-btn" disabled>Move Selected Faces</button>
            <button onclick="refreshData()">Refresh</button>
        </div>
        
        <div id="status-message" style="margin-top: 15px;"></div>
    </div>

    <!-- Rename Modal -->
    <div id="rename-modal" class="modal">
        <div class="modal-content">
            <h3>Rename Person Directory</h3>
            <p id="rename-current-name"></p>
            <input type="text" id="rename-input" placeholder="Enter new name...">
            <div class="modal-buttons">
                <button onclick="confirmRename()">Rename</button>
                <button onclick="closeRenameModal()">Cancel</button>
            </div>
        </div>
    </div>

    <script>
        // Application state
        let allFaces = [];
        let filteredFaces = [];
        let currentPage = 0;
        let pageSize = 100;
        let selectedFaces = new Set();
        let selectedPerson = null;
        let people = [];
        let renamePersonName = null;
        
        // Initialize the application
        async function init() {
            await loadData();
            setupEventListeners();
        }
        
        // Load all data
        async function loadData() {
            try {
                await Promise.all([loadFaces(), loadPeople(), loadStats()]);
                updateDisplay();
            } catch (error) {
                showStatus('Error loading data: ' + error.message, 'error');
            }
        }
        
        // Load face data from API
        async function loadFaces() {
            try {
                const response = await fetch('/api/faces');
                if (!response.ok) throw new Error('Failed to load faces');
                
                allFaces = await response.json();
                filteredFaces = [...allFaces];
                
                // Populate filter dropdowns
                populateFilters();
            } catch (error) {
                console.error('Error loading faces:', error);
                showStatus('Error loading faces: ' + error.message, 'error');
            }
        }
        
        // Load people directories from API
        async function loadPeople() {
            try {
                const response = await fetch('/api/people');
                if (!response.ok) throw new Error('Failed to load people');
                
                people = await response.json();
                updatePeopleDisplay();
            } catch (error) {
                console.error('Error loading people:', error);
                showStatus('Error loading people: ' + error.message, 'error');
            }
        }
        
        // Load statistics from API
        async function loadStats() {
            try {
                const response = await fetch('/api/stats');
                if (!response.ok) throw new Error('Failed to load stats');
                
                const stats = await response.json();
                updateStats(stats);
            } catch (error) {
                console.error('Error loading stats:', error);
            }
        }
        
        // Update statistics display
        function updateStats(stats) {
            document.getElementById('unknown-faces').textContent = stats.unknown_faces || 0;
            document.getElementById('selected-count').textContent = selectedFaces.size;
            document.getElementById('person-groups').textContent = stats.person_groups || 0;
            document.getElementById('identified-people').textContent = stats.identified_people || 0;
            document.getElementById('total-training').textContent = stats.total_training_photos || 0;
        }
        
        // Populate filter dropdowns
        function populateFilters() {
            // Populate directory filter
            const directories = [...new Set(allFaces.map(face => face.directory))];
            const directorySelect = document.getElementById('directory-filter');
            directorySelect.innerHTML = '<option value="">All directories</option>';
            directories.forEach(dir => {
                const option = document.createElement('option');
                option.value = dir;
                option.textContent = dir;
                directorySelect.appendChild(option);
            });
            
            // Populate source filter
            const sources = [...new Set(allFaces.map(face => face.source))];
            const sourceSelect = document.getElementById('source-filter');
            sourceSelect.innerHTML = '<option value="">All photos</option>';
            sources.forEach(source => {
                const option = document.createElement('option');
                option.value = source;
                option.textContent = source;
                sourceSelect.appendChild(option);
            });
        }
        
        // Update the face grid display
        function updateDisplay() {
            const startIndex = currentPage * pageSize;
            const endIndex = Math.min(startIndex + pageSize, filteredFaces.length);
            const facesToShow = filteredFaces.slice(startIndex, endIndex);
            
            const grid = document.getElementById('face-grid');
            
            if (facesToShow.length === 0) {
                grid.innerHTML = '<div class="loading">No faces to display</div>';
                return;
            }
            
            grid.innerHTML = facesToShow.map(face => `
                <div class="face-item ${selectedFaces.has(face.filename) ? 'selected' : ''}" 
                     data-filename="${face.filename}">
                    <input type="checkbox" class="checkbox" 
                           ${selectedFaces.has(face.filename) ? 'checked' : ''}
                           onchange="toggleFace('${face.filename}')">
                    <img src="/${face.path}" 
                         alt="${face.filename}"
                         onclick="toggleFace('${face.filename}')"
                         onerror="this.src='data:image/svg+xml;base64,${generatePlaceholderImage(face.filename)}'">
                    <div class="face-info">
                        <div class="face-directory">${face.directory}</div>
                        <div>${face.filename}</div>
                        <div>${(face.size / 1024).toFixed(1)}KB</div>
                    </div>
                </div>
            `).join('');
            
            updatePagination();
            updateSelectedCount();
        }
        
        // Generate placeholder image for missing images
        function generatePlaceholderImage(filename) {
            const hash = filename.split('').reduce((a, b) => {
                a = ((a << 5) - a) + b.charCodeAt(0);
                return a & a;
            }, 0);
            
            const color = `hsl(${Math.abs(hash) % 360}, 70%, 80%)`;
            const svg = `<svg width="150" height="150" xmlns="http://www.w3.org/2000/svg">
                <rect width="150" height="150" fill="${color}"/>
                <circle cx="75" cy="60" r="20" fill="white" opacity="0.7"/>
                <circle cx="75" cy="110" r="25" fill="white" opacity="0.5"/>
                <text x="75" y="140" text-anchor="middle" font-size="10" fill="black" opacity="0.6">FACE</text>
            </svg>`;
            
            return btoa(svg);
        }
        
        // Update pagination controls
        function updatePagination() {
            const totalPages = Math.ceil(filteredFaces.length / pageSize);
            const pageInfo = `Page ${currentPage + 1} of ${totalPages}`;
            
            // Update both pagination areas
            document.querySelectorAll('#top-pagination span, #bottom-pagination span').forEach(span => {
                span.textContent = pageInfo;
            });
            
            // Update button states
            const prevBtns = document.querySelectorAll('#top-pagination button:first-child, #bottom-pagination button:first-child');
            const nextBtns = document.querySelectorAll('#top-pagination button:last-child, #bottom-pagination button:last-child');
            
            prevBtns.forEach(btn => btn.disabled = currentPage === 0);
            nextBtns.forEach(btn => btn.disabled = currentPage >= totalPages - 1);
        }
        
        // Update people directory display
        function updatePeopleDisplay() {
            const grid = document.getElementById('person-grid');
            
            if (people.length === 0) {
                grid.innerHTML = '<div class="loading">No people directories found</div>';
                return;
            }
            
            grid.innerHTML = people.map(person => `
                <div class="person-item ${selectedPerson === person.name ? 'selected' : ''} ${person.is_person_group ? 'person-group' : 'identified'}" 
                     onclick="selectPerson('${person.name}')">
                    ${person.is_person_group ? `<button class="rename-btn" onclick="event.stopPropagation(); showRenameModal('${person.name}')">Rename</button>` : ''}
                    <strong>${person.name}</strong><br>
                    <small>${person.count} training photos</small>
                </div>
            `).join('');
        }
        
        // Update selected count in stats
        function updateSelectedCount() {
            document.getElementById('selected-count').textContent = selectedFaces.size;
            
            // Update move button state
            const moveBtn = document.getElementById('move-btn');
            moveBtn.disabled = !selectedPerson || selectedFaces.size === 0;
        }
        
        // Toggle face selection
        function toggleFace(filename) {
            if (selectedFaces.has(filename)) {
                selectedFaces.delete(filename);
            } else {
                selectedFaces.add(filename);
            }
            
            updateDisplay();
        }
        
        // Select person directory
        function selectPerson(personName) {
            selectedPerson = selectedPerson === personName ? null : personName;
            updatePeopleDisplay();
            updateSelectedCount();
        }
        
        // Pagination functions
        function nextPage() {
            const totalPages = Math.ceil(filteredFaces.length / pageSize);
            if (currentPage < totalPages - 1) {
                currentPage++;
                updateDisplay();
            }
        }
        
        function previousPage() {
            if (currentPage > 0) {
                currentPage--;
                updateDisplay();
            }
        }
        
        // Selection functions
        function selectAll() {
            const startIndex = currentPage * pageSize;
            const endIndex = Math.min(startIndex + pageSize, filteredFaces.length);
            const facesToShow = filteredFaces.slice(startIndex, endIndex);
            
            facesToShow.forEach(face => selectedFaces.add(face.filename));
            updateDisplay();
        }
        
        function selectNone() {
            selectedFaces.clear();
            updateDisplay();
        }
        
        // Move selected faces to chosen person
        async function moveToSelected() {
            if (!selectedPerson || selectedFaces.size === 0) {
                showStatus('Please select both faces and a person directory.', 'error');
                return;
            }
            
            const facesToMove = Array.from(selectedFaces);
            
            try {
                showStatus(`Moving ${facesToMove.length} faces to ${selectedPerson}...`, 'info');
                
                const response = await fetch('/api/move-faces', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        faces: facesToMove,
                        person: selectedPerson
                    })
                });
                
                if (!response.ok) throw new Error('Failed to move faces');
                
                const result = await response.json();
                
                if (result.errors && result.errors.length > 0) {
                    showStatus(`Moved ${result.moved_count} faces. Errors: ${result.errors.join(', ')}`, 'error');
                } else {
                    showStatus(`Successfully moved ${result.moved_count} faces to ${selectedPerson}!`, 'success');
                }
                
                // Refresh data to reflect changes
                selectedFaces.clear();
                selectedPerson = null;
                await loadData();
                
            } catch (error) {
                showStatus('Error moving faces: ' + error.message, 'error');
            }
        }
        
        // Delete selected faces
        async function deleteSelected() {
            if (selectedFaces.size === 0) {
                showStatus('Please select faces to delete.', 'error');
                return;
            }
            
            const confirmed = confirm(`Delete ${selectedFaces.size} selected faces? This cannot be undone.`);
            if (!confirmed) return;
            
            const facesToDelete = Array.from(selectedFaces);
            
            try {
                showStatus(`Deleting ${facesToDelete.length} faces...`, 'info');
                
                const response = await fetch('/api/delete-faces', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        faces: facesToDelete
                    })
                });
                
                if (!response.ok) throw new Error('Failed to delete faces');
                
                const result = await response.json();
                
                if (result.errors && result.errors.length > 0) {
                    showStatus(`Deleted ${result.deleted_count} faces. Errors: ${result.errors.join(', ')}`, 'error');
                } else {
                    showStatus(`Successfully deleted ${result.deleted_count} faces!`, 'success');
                }
                
                // Refresh data to reflect changes
                selectedFaces.clear();
                await loadData();
                
            } catch (error) {
                showStatus('Error deleting faces: ' + error.message, 'error');
            }
        }
        
        // Create new person directory
        async function createNewPerson() {
            const nameInput = document.getElementById('new-person-name');
            const personName = nameInput.value.trim();
            
            if (!personName) {
                showStatus('Please enter a person name.', 'error');
                return;
            }
            
            if (people.some(p => p.name === personName)) {
                showStatus('Person directory already exists.', 'error');
                return;
            }
            
            try {
                const response = await fetch('/api/create-person', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        name: personName
                    })
                });
                
                if (!response.ok) throw new Error('Failed to create person directory');
                
                nameInput.value = '';
                showStatus(`Created directory for ${personName}`, 'success');
                await loadPeople();
                
            } catch (error) {
                showStatus('Error creating person directory: ' + error.message, 'error');
            }
        }
        
        // Show rename modal
        function showRenameModal(personName) {
            renamePersonName = personName;
            document.getElementById('rename-current-name').textContent = `Current name: ${personName}`;
            document.getElementById('rename-input').value = '';
            document.getElementById('rename-modal').style.display = 'block';
            document.getElementById('rename-input').focus();
        }
        
        // Close rename modal
        function closeRenameModal() {
            document.getElementById('rename-modal').style.display = 'none';
            renamePersonName = null;
        }
        
        // Confirm rename
        async function confirmRename() {
            const newName = document.getElementById('rename-input').value.trim();
            
            if (!newName) {
                showStatus('Please enter a new name.', 'error');
                return;
            }
            
            if (people.some(p => p.name === newName)) {
                showStatus('A directory with that name already exists.', 'error');
                return;
            }
            
            try {
                const response = await fetch('/api/rename-person', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        old_name: renamePersonName,
                        new_name: newName
                    })
                });
                
                if (!response.ok) throw new Error('Failed to rename directory');
                
                showStatus(`Renamed ${renamePersonName} to ${newName}`, 'success');
                closeRenameModal();
                await loadPeople();
                
            } catch (error) {
                showStatus('Error renaming directory: ' + error.message, 'error');
            }
        }
        
        // Apply filters and sorting
        function applyFilters() {
            const directoryFilter = document.getElementById('directory-filter').value;
            const sourceFilter = document.getElementById('source-filter').value;
            const sortOrder = document.getElementById('sort-order').value;
            
            // Filter faces
            filteredFaces = allFaces.filter(face => {
                if (directoryFilter && face.directory !== directoryFilter) return false;
                if (sourceFilter && face.source !== sourceFilter) return false;
                return true;
            });
            
            // Sort faces
            filteredFaces.sort((a, b) => {
                switch (sortOrder) {
                    case 'directory':
                        return b.directory - a.directory;
                    case 'date':
                        return new Date(b.date) - new Date(a.date);
                    case 'size':
                        return b.size - a.size;
                    case 'name':
                    default:
                        return a.filename.localeCompare(b.filename);
                }
            });
            
            currentPage = 0;
            updateDisplay();
        }
        
        // Refresh all data
        async function refreshData() {
            showStatus('Refreshing data...', 'info');
            try {
                await loadData();
                showStatus('Data refreshed successfully!', 'success');
            } catch (error) {
                showStatus('Error refreshing data: ' + error.message, 'error');
            }
        }
        
        // Show status message
        function showStatus(message, type = 'info') {
            const statusEl = document.getElementById('status-message');
            statusEl.textContent = message;
            statusEl.className = type;
            
            if (type === 'success' || type === 'info') {
                setTimeout(() => statusEl.textContent = '', 5000);
            }
        }
        
        // Setup event listeners
        function setupEventListeners() {
            // Filter controls
            document.getElementById('directory-filter').addEventListener('change', applyFilters);
            document.getElementById('source-filter').addEventListener('change', applyFilters);
            document.getElementById('sort-order').addEventListener('change', applyFilters);
            document.getElementById('page-size').addEventListener('change', (e) => {
                pageSize = parseInt(e.target.value);
                currentPage = 0;
                updateDisplay();
            });
            
            // Keyboard shortcuts
            document.addEventListener('keydown', (e) => {
                // Don't trigger shortcuts when typing in input fields
                if (e.target.tagName === 'INPUT') return;
                
                if (e.ctrlKey || e.metaKey) {
                    switch (e.key) {
                        case 'a':
                            e.preventDefault();
                            selectAll();
                            break;
                        case 'd':
                            e.preventDefault();
                            selectNone();
                            break;
                    }
                }
                
                // Arrow keys for pagination
                if (e.key === 'ArrowLeft' && currentPage > 0) {
                    e.preventDefault();
                    previousPage();
                } else if (e.key === 'ArrowRight') {
                    e.preventDefault();
                    nextPage();
                }
                
                // Escape to close modal
                if (e.key === 'Escape') {
                    closeRenameModal();
                }
            });
            
            // Enter key in rename input
            document.getElementById('rename-input').addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    confirmRename();
                }
            });
            
            // Enter key in new person input
            document.getElementById('new-person-name').addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    createNewPerson();
                }
            });
            
            // Close modal when clicking outside
            document.getElementById('rename-modal').addEventListener('click', (e) => {
                if (e.target === e.currentTarget) {
                    closeRenameModal();
                }
            });
        }
        
        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', init);
    </script>
</body>
</html>'''

def create_handler_with_config(config_file):
    """Create a handler class with the specified config file"""
    class ConfiguredHandler(FaceSorterHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, config_file=config_file, **kwargs)
    return ConfiguredHandler

def main():
    parser = argparse.ArgumentParser(description='Face Sorter Web Server')
    parser.add_argument('--port', '-p', type=int, default=8080, help='Port to run server on (default: 8080)')
    parser.add_argument('--config', '-c', default='AlbumSettings.default.txt', help='Configuration file to use')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.config):
        print(f"Warning: Configuration file {args.config} not found")
        print("Using default settings")
    
    # Create handler class with config
    handler_class = create_handler_with_config(args.config)
    
    # Create and start server
    server = HTTPServer((args.host, args.port), handler_class)
    
    print(f"Face Sorter Web Server starting...")
    print(f"Configuration: {args.config}")
    print(f"Server URL: http://{args.host}:{args.port}")
    print(f"Press Ctrl+C to stop the server")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        server.shutdown()
        server.server_close()

if __name__ == '__main__':
    main()