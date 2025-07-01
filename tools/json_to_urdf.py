#!/usr/bin/env python3
"""
JSON to URDF Converter
Converts exported WebXR mesh data to URDF format for robotics simulation
"""

import json
import os
import sys
import math
import argparse
from pathlib import Path
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

class JSONToURDFConverter:
    def __init__(self):
        self.mesh_counter = 0
        self.link_counter = 0
        
    def load_json_file(self, filepath):
        """Load and parse JSON file"""
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
            return data
        except Exception as e:
            print(f"Error loading JSON file {filepath}: {e}")
            return None
    
    def matrix_to_pose(self, matrix):
        """Convert 4x4 transformation matrix to position and orientation"""
        if len(matrix) != 16:
            return [0, 0, 0], [0, 0, 0]
        
        # Extract position (translation)
        x = matrix[12]
        y = matrix[13] 
        z = matrix[14]
        
        # Extract rotation matrix (3x3 from 4x4)
        r11, r12, r13 = matrix[0], matrix[1], matrix[2]
        r21, r22, r23 = matrix[4], matrix[5], matrix[6]
        r31, r32, r33 = matrix[8], matrix[9], matrix[10]
        
        # Convert rotation matrix to Euler angles (roll, pitch, yaw)
        # Using ZYX convention (yaw, pitch, roll)
        sy = math.sqrt(r11 * r11 + r21 * r21)
        
        singular = sy < 1e-6
        
        if not singular:
            roll = math.atan2(r32, r33)
            pitch = math.atan2(-r31, sy)
            yaw = math.atan2(r21, r11)
        else:
            roll = math.atan2(-r23, r22)
            pitch = math.atan2(-r31, sy)
            yaw = 0
            
        return [x, y, z], [roll, pitch, yaw]
    
    def get_mesh_dimensions(self, obj):
        """Extract dimensions from mesh object"""
        # Default dimensions
        width, height, depth = 1.0, 1.0, 1.0
        
        # Try to extract from geometry if available
        if 'geometry' in obj:
            geom = obj['geometry']
            if geom.get('type') == 'BoxGeometry':
                # Box geometry parameters
                if 'parameters' in geom:
                    params = geom['parameters']
                    width = params.get('width', 1.0)
                    height = params.get('height', 1.0) 
                    depth = params.get('depth', 1.0)
        
        return width, height, depth
    
    def create_urdf_link(self, parent, name, obj):
        """Create a URDF link element"""
        link = SubElement(parent, 'link', name=name)
        
        # Visual element
        visual = SubElement(link, 'visual')
        
        # Geometry
        geometry = SubElement(visual, 'geometry')
        
        # Get object type and create appropriate geometry
        obj_type = obj.get('type', 'Mesh')
        
        if obj_type in ['DirectionalLight', 'HemisphereLight']:
            # Skip lights - they don't have physical geometry
            parent.remove(link)
            return None
            
        elif 'Mesh' in obj_type or obj.get('name') in ['Wireframe Mesh', 'Plane', 'Furniture']:
            # Create a box for mesh objects
            box = SubElement(geometry, 'box')
            width, height, depth = self.get_mesh_dimensions(obj)
            box.set('size', f"{width} {height} {depth}")
            
        else:
            # Default to a small box
            box = SubElement(geometry, 'box')
            box.set('size', "0.1 0.1 0.1")
        
        # Material (optional)
        material = SubElement(visual, 'material', name=f"{name}_material")
        color = SubElement(material, 'color')
        
        # Try to extract color from object
        if 'material' in obj and 'color' in obj['material']:
            # Convert hex color to RGB
            hex_color = obj['material']['color']
            r = ((hex_color >> 16) & 255) / 255.0
            g = ((hex_color >> 8) & 255) / 255.0
            b = (hex_color & 255) / 255.0
            color.set('rgba', f"{r} {g} {b} 1.0")
        else:
            color.set('rgba', "0.8 0.8 0.8 1.0")
        
        # Collision (same as visual for simplicity)
        collision = SubElement(link, 'collision')
        collision_geom = SubElement(collision, 'geometry')
        collision_box = SubElement(collision_geom, 'box')
        collision_box.set('size', box.get('size'))
        
        # Inertial properties
        inertial = SubElement(link, 'inertial')
        mass = SubElement(inertial, 'mass')
        mass.set('value', "1.0")
        
        inertia = SubElement(inertial, 'inertia')
        inertia.set('ixx', "0.1")
        inertia.set('iyy', "0.1") 
        inertia.set('izz', "0.1")
        inertia.set('ixy', "0.0")
        inertia.set('ixz', "0.0")
        inertia.set('iyz', "0.0")
        
        return link
    
    def create_urdf_joint(self, parent, name, parent_link, child_link, pose):
        """Create a URDF joint element"""
        joint = SubElement(parent, 'joint', name=name, type='fixed')
        
        # Parent and child links
        parent_elem = SubElement(joint, 'parent', link=parent_link)
        child_elem = SubElement(joint, 'child', link=child_link)
        
        # Origin (pose)
        position, orientation = pose
        origin = SubElement(joint, 'origin')
        origin.set('xyz', f"{position[0]} {position[1]} {position[2]}")
        origin.set('rpy', f"{orientation[0]} {orientation[1]} {orientation[2]}")
        
        return joint
    
    def process_children(self, urdf_root, children, parent_link_name="world"):
        """Recursively process children objects"""
        for i, child in enumerate(children):
            # Skip lights and other non-physical objects
            child_type = child.get('type', 'Mesh')
            if child_type in ['DirectionalLight', 'HemisphereLight', 'AmbientLight']:
                continue
                
            # Create link name
            child_name = child.get('name', f'link_{self.link_counter}')
            child_name = child_name.replace(' ', '_').replace('-', '_')
            self.link_counter += 1
            
            # Create link
            link = self.create_urdf_link(urdf_root, child_name, child)
            if link is None:
                continue
                
            # Get pose from matrix
            matrix = child.get('matrix', [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
            pose = self.matrix_to_pose(matrix)
            
            # Create joint if not the first link
            if parent_link_name != "world":
                joint_name = f"joint_{child_name}"
                self.create_urdf_joint(urdf_root, joint_name, parent_link_name, child_name, pose)
            
            # Process grandchildren
            if 'children' in child and child['children']:
                self.process_children(urdf_root, child['children'], child_name)
    
    def convert_json_to_urdf(self, json_filepath, output_filepath):
        """Convert JSON scene to URDF"""
        print(f"Converting {json_filepath} to URDF...")
        
        # Load JSON data
        data = self.load_json_file(json_filepath)
        if data is None:
            return False
        
        # Create URDF root element
        robot = Element('robot', name='webxr_scene')
        
        # Add base link
        base_link = SubElement(robot, 'link', name='base_link')
        base_visual = SubElement(base_link, 'visual')
        base_geometry = SubElement(base_visual, 'geometry')
        base_box = SubElement(base_geometry, 'box')
        base_box.set('size', '0.01 0.01 0.01')  # Very small base
        
        # Process scene object
        scene_obj = data.get('object', {})
        children = scene_obj.get('children', [])
        
        # Process all children
        self.process_children(robot, children, 'base_link')
        
        # Convert to pretty XML string
        rough_string = tostring(robot, 'unicode')
        reparsed = minidom.parseString(rough_string)
        pretty_xml = reparsed.toprettyxml(indent="  ")
        
        # Remove empty lines
        pretty_xml = '\n'.join([line for line in pretty_xml.split('\n') if line.strip()])
        
        # Write to file
        try:
            with open(output_filepath, 'w') as f:
                f.write(pretty_xml)
            print(f"URDF saved to: {output_filepath}")
            return True
        except Exception as e:
            print(f"Error saving URDF: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Convert WebXR JSON exports to URDF')
    parser.add_argument('input', help='Input JSON file or directory containing JSON files')
    parser.add_argument('-o', '--output', help='Output directory (default: urdf_exports)')
    parser.add_argument('--single', action='store_true', help='Process single file instead of directory')
    
    args = parser.parse_args()
    
    converter = JSONToURDFConverter()
    
    input_path = Path(args.input)
    output_dir = Path(args.output or 'urdf_exports')
    
    # Create output directory
    output_dir.mkdir(exist_ok=True)
    
    if args.single or input_path.is_file():
        # Process single file
        if not input_path.exists():
            print(f"Error: File {input_path} does not exist")
            return 1
            
        output_file = output_dir / (input_path.stem + '.urdf')
        success = converter.convert_json_to_urdf(input_path, output_file)
        return 0 if success else 1
    
    else:
        # Process directory
        if not input_path.is_dir():
            print(f"Error: Directory {input_path} does not exist")
            return 1
        
        # Find all scene JSON files
        scene_files = list(input_path.glob('scene_*.json'))
        
        if not scene_files:
            print(f"No scene_*.json files found in {input_path}")
            return 1
        
        success_count = 0
        for json_file in scene_files:
            output_file = output_dir / (json_file.stem + '.urdf')
            if converter.convert_json_to_urdf(json_file, output_file):
                success_count += 1
        
        print(f"\nProcessed {success_count}/{len(scene_files)} files successfully")
        return 0 if success_count > 0 else 1

if __name__ == '__main__':
    sys.exit(main())
