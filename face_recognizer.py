#!/usr/bin/env python3
"""
Face Recognition Module for Photo Album Generator
Integrates with MakeAlbum.pl to detect and identify faces in photos
"""

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
                
            print(f"  Training on photos of {person_dir}...")
            
            # Process each image in the person's directory
            image_files = [f for f in os.listdir(person_path) 
                          if f.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp'))]
            
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
            
            print(f"    Found {faces_found} usable face(s) for {person_dir}")
        
        if len(self.known_face_encodings) > 0:
            self.save_model()
            print(f"Training complete! Saved {len(self.known_face_encodings)} face encodings for {len(set(self.known_face_names))} people.")
            return True
        else:
            print("No faces were successfully encoded during training!")
            return False
    
    def recognize_faces_in_image(self, image_path, unknown_label="@UnknownPerson", save_unknown_faces=False, unknown_faces_dir=None):
        """
        Recognize faces in a single image
        Returns list of recognized names
        Optionally saves unknown faces to specified directory
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
            unknown_face_count = 0
            
            for i, face_encoding in enumerate(face_encodings):
                # Compare with known faces
                matches = face_recognition.compare_faces(
                    self.known_face_encodings, 
                    face_encoding, 
                    tolerance=1.0 - self.confidence_threshold
                )
                
                name = unknown_label
                is_unknown = True
                
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
                        is_unknown = False
                
                recognized_names.append(name)
                
                # Save unknown faces if requested
                if is_unknown and save_unknown_faces and unknown_faces_dir:
                    self._save_unknown_face(image, face_locations[i], image_path, unknown_face_count, unknown_faces_dir)
                    unknown_face_count += 1
            
            # Remove duplicates while preserving order
            unique_names = []
            for name in recognized_names:
                if name not in unique_names:
                    unique_names.append(name)
            
            return unique_names
            
        except Exception as e:
            print(f"Error processing {image_path}: {e}")
            return []
    
    def _save_unknown_face(self, image, face_location, source_image_path, face_index, unknown_faces_dir):
        """
        Save a cropped unknown face to the unknown faces directory
        """
        try:
            # Ensure unknown faces directory exists
            if not os.path.exists(unknown_faces_dir):
                os.makedirs(unknown_faces_dir)
            
            # Extract face location coordinates
            top, right, bottom, left = face_location
            
            # Add some padding around the face (10% on each side)
            height = bottom - top
            width = right - left
            padding_h = int(height * 0.1)
            padding_w = int(width * 0.1)
            
            # Expand the crop area with padding, ensuring we don't go outside image bounds
            top = max(0, top - padding_h)
            bottom = min(image.shape[0], bottom + padding_h)
            left = max(0, left - padding_w)
            right = min(image.shape[1], right + padding_w)
            
            # Crop the face from the image
            face_image = image[top:bottom, left:right]
            
            # Convert from RGB to BGR for OpenCV
            face_image_bgr = cv2.cvtColor(face_image, cv2.COLOR_RGB2BGR)
            
            # Generate filename based on source image
            source_filename = os.path.basename(source_image_path)
            source_name, source_ext = os.path.splitext(source_filename)
            
            # Create unique filename for this face
            face_filename = f"{source_name}_face{face_index:02d}.jpg"
            face_path = os.path.join(unknown_faces_dir, face_filename)
            
            # Don't overwrite existing files
            counter = 1
            while os.path.exists(face_path):
                face_filename = f"{source_name}_face{face_index:02d}_{counter:02d}.jpg"
                face_path = os.path.join(unknown_faces_dir, face_filename)
                counter += 1
            
            # Save the face image
            cv2.imwrite(face_path, face_image_bgr)
            print(f"Saved unknown face: {face_filename}")
            
        except Exception as e:
            print(f"Error saving unknown face from {source_image_path}: {e}")
    
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
        print("  python face_recognizer.py train                                    # Train the model")
        print("  python face_recognizer.py recognize <image_path> [options]         # Recognize faces in image")
        print("    Options:")
        print("      --save-unknown                     # Save unknown faces to directory")
        print("      --unknown-dir <path>               # Directory for unknown faces (default: faces/Unknown)")
        print("  python face_recognizer.py stats                                    # Show model statistics")
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
        
        # Check for optional parameters
        save_unknown = "--save-unknown" in sys.argv
        unknown_dir = None
        
        if save_unknown:
            # Look for --unknown-dir parameter
            try:
                unknown_dir_index = sys.argv.index("--unknown-dir")
                if unknown_dir_index + 1 < len(sys.argv):
                    unknown_dir = sys.argv[unknown_dir_index + 1]
                else:
                    unknown_dir = "faces/Unknown"
            except ValueError:
                unknown_dir = "faces/Unknown"
        
        names = recognizer.recognize_faces_in_image(image_path, save_unknown_faces=save_unknown, unknown_faces_dir=unknown_dir)
        
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