#!/usr/bin/env python3
import face_recognition
import numpy as np
import os
import sys
import json
from pathlib import Path

def group_similar_faces(unknown_dir, tolerance=0.6):
    """Group similar faces using face encodings"""
    
    if not os.path.exists(unknown_dir):
        return []
    
    # Get all face files
    face_files = []
    for ext in ['jpg', 'jpeg', 'png', 'bmp']:
        face_files.extend(Path(unknown_dir).glob(f'*.{ext}'))
        face_files.extend(Path(unknown_dir).glob(f'*.{ext.upper()}'))
    
    if not face_files:
        return []
    
    # Calculate encodings for all faces
    encodings = []
    file_names = []
    
    for face_file in face_files:
        try:
            image = face_recognition.load_image_file(str(face_file))
            face_encodings = face_recognition.face_encodings(image)
            
            if face_encodings:
                encodings.append(face_encodings[0])
                file_names.append(face_file.name)
        except Exception as e:
            continue
    
    if not encodings:
        return []
    
    # Group similar faces
    groups = []
    used = set()
    
    for i, encoding1 in enumerate(encodings):
        if i in used:
            continue
            
        group = [file_names[i]]
        used.add(i)
        
        for j, encoding2 in enumerate(encodings):
            if j in used:
                continue
            
            distance = face_recognition.face_distance([encoding1], encoding2)[0]
            if distance < tolerance:
                group.append(file_names[j])
                used.add(j)
        
        if len(group) > 1:  # Only include groups with multiple faces
            groups.append(group)
    
    return groups

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python face_grouper.py <unknown_faces_directory>")
        sys.exit(1)
    
    unknown_dir = sys.argv[1]
    groups = group_similar_faces(unknown_dir)
    print(json.dumps(groups))
