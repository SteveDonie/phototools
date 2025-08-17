#!/usr/bin/env python3
"""
face_recognizer.py
Face Recognition Module for Photo Album Generator
Integrates with MakeAlbum.pl to detect and identify faces in photos
"""

import face_recognition_models
import face_recognition
import cv2
import numpy as np
import pickle
import os
import sys
import json
from pathlib import Path

class FaceRecognizer:
    def __init__(self, training_dir="faces", model_file="face_encodings.pkl", confidence_threshold=0.6):
        self.training_dir = training_dir
        self.model_file = model_file
        self.confidence_threshold = confidence_threshold
        self.known_face_encodings = []
        self.known_face_names = []
        
    def load_model(self):
        """Load the trained face encodings from file"""
        if os.path.exists(self.model_file):
            with open(self.model_file, 'rb') as f:
                data = pickle.load(f)
                self.known_face_encodings = data['encodings']
                self.known_face_names = data['names']
            return True
        return False
    
    def save_model(self):
        """Save the trained face encodings to file"""
        data = {
            'encodings': self.known_face_encodings,
            'names': self.known_face_names
        }
        with open(self.model_file, 'wb') as f:
            pickle.dump(data, f)
    
    def train_from_directory(self):
        """Train the face recognition model from the training directory structure"""
        if not os.path.exists(self.training_dir):
            print(f"Training directory '{self.training_dir}' not found!")
            return False
        
        self.known_face_encodings = []
        self.known_face_names = []
        
        print(f"Training face recognition model from '{self.training_dir}'...")
        
        # Walk through each person's directory
        for person_dir in os.listdir(self.training_dir):
            person_path = os.path.join(self.training_dir, person_dir)
            if not os.path.isdir(person_path):
                continue
                
            
            # Process each image in the person's directory
            image_files = [f for f in os.listdir(person_path) 
                          if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]

            print(f"  Training on {len(image_files)} photos of {person_dir}...")
            
            if not image_files:
                print(f"    Warning: No image files found in {person_path}")
                continue
            
            faces_found = 0
            for image_file in image_files:
                image_path = os.path.join(person_path, image_file)
                
                try:
                    # Load image and find face encodings
                    image = face_recognition.load_image_file(image_path)
                    face_encodings = face_recognition.face_encodings(image)
                    
                    if len(face_encodings) > 0:
                        # Use the first face found (assuming one person per training image)
                        face_encoding = face_encodings[0]
                        self.known_face_encodings.append(face_encoding)
                        self.known_face_names.append(person_dir)
                        faces_found += 1
                    else:
                        print(f"    Warning: No face found in {image_file}")
                        
                except Exception as e:
                    print(f"    Error processing {image_file}: {e}")
            
            print(f"    Found {faces_found} usable face(s) for {person_dir} containing {len(image_files)} image files")
        
        if len(self.known_face_encodings) > 0:
            self.save_model()
            print(f"Training complete! Saved {len(self.known_face_encodings)} face encodings for {len(set(self.known_face_names))} people.")
            return True
        else:
            print("No faces were successfully encoded during training!")
            return False
    
    def recognize_faces_in_image(self, image_path, unknown_label="@UnknownPerson"):
        """
        Recognize faces in a single image
        Returns list of recognized names
        """
        if not os.path.exists(image_path):
            return []
        
        if len(self.known_face_encodings) == 0:
            if not self.load_model():
                return []
        
        try:
            # Load the image
            image = face_recognition.load_image_file(image_path)
            
            # Find all face locations and encodings in the image
            face_locations = face_recognition.face_locations(image)
            face_encodings = face_recognition.face_encodings(image, face_locations)
            
            recognized_names = []
            
            for face_encoding in face_encodings:
                # Compare with known faces
                matches = face_recognition.compare_faces(
                    self.known_face_encodings, 
                    face_encoding, 
                    tolerance=1.0 - self.confidence_threshold
                )
                
                name = unknown_label
                
                # If we found matches, use the best one
                if True in matches:
                    # Calculate distances to all known faces
                    face_distances = face_recognition.face_distance(
                        self.known_face_encodings, 
                        face_encoding
                    )
                    
                    # Get the index of the best match
                    best_match_index = np.argmin(face_distances)
                    
                    if matches[best_match_index] and face_distances[best_match_index] < (1.0 - self.confidence_threshold):
                        name = self.known_face_names[best_match_index]
                
                recognized_names.append(name)
            
            # Remove duplicates while preserving order
            unique_names = []
            for name in recognized_names:
                if name not in unique_names:
                    unique_names.append(name)
            
            return unique_names
            
        except Exception as e:
            print(f"Error processing {image_path}: {e}")
            return []
    
    def get_stats(self):
        """Get statistics about the trained model"""
        if len(self.known_face_encodings) == 0:
            self.load_model()
        
        unique_people = set(self.known_face_names)
        stats = {
            'total_encodings': len(self.known_face_encodings),
            'unique_people': len(unique_people),
            'people': list(unique_people)
        }
        return stats

def main():
    """Command line interface for face recognition"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python face_recognizer.py train                    # Train the model")
        print("  python face_recognizer.py recognize <image_path>   # Recognize faces in image")
        print("  python face_recognizer.py stats                    # Show model statistics")
        sys.exit(1)
    
    recognizer = FaceRecognizer()
    
    command = sys.argv[1].lower()
    
    if command == "train":
        success = recognizer.train_from_directory()
        sys.exit(0 if success else 1)
        
    elif command == "recognize":
        if len(sys.argv) < 3:
            print("Error: Please provide an image path")
            sys.exit(1)
        
        image_path = sys.argv[2]
        names = recognizer.recognize_faces_in_image(image_path)
        
        # Output as JSON for easy parsing by Perl
        result = {
            'image_path': image_path,
            'recognized_faces': names
        }
        print(json.dumps(result))
        
    elif command == "stats":
        stats = recognizer.get_stats()
        print(json.dumps(stats, indent=2))
        
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()