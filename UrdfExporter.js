// URDF Exporter Module for WebXR Mesh Exporter
// Exports ThreeJS scenes to URDF format and communicates with server

export class UrdfExporter {
  constructor(socket = null) {
    this.socket = socket;
    this.meshCounter = 0;
    this.linkCounter = 0;
  }

  // Set socket connection for server communication
  setSocket(socket) {
    this.socket = socket;
  }

  // Convert ThreeJS scene to URDF format
  exportSceneToUrdf(scene, robotName = "webxr_robot", options = {}) {
    const {
      removeControllers = true,
      removeBalls = true,
      removeUI = true,
      baseLink = "base_link"
    } = options;

    // Clone scene to avoid modifying original
    const clonedScene = this.cloneScene(scene);
    
    // Clean up scene (remove controllers, UI elements, etc.)
    if (removeControllers) {
      this.removeControllers(clonedScene);
    }
    if (removeBalls) {
      this.removeBalls(clonedScene);
    }
    if (removeUI) {
      this.removeUIElements(clonedScene);
    }

    // Generate URDF content
    const urdfContent = this.generateUrdf(clonedScene, robotName, baseLink);
    
    // Generate package structure with meshes
    const packageData = this.generatePackageData(clonedScene, robotName);

    return {
      urdf: urdfContent,
      package: packageData,
      robotName
    };
  }

  // Export and download URDF
  exportAndDownload(scene, robotName = "webxr_robot", options = {}) {
    const exportData = this.exportSceneToUrdf(scene, robotName, options);
    
    // Download URDF file
    this.downloadFile(exportData.urdf, `${robotName}.urdf`, 'application/xml');
    
    // Download package.xml
    this.downloadFile(exportData.package.packageXml, 'package.xml', 'application/xml');
    
    // Download CMakeLists.txt
    this.downloadFile(exportData.package.cmakeLists, 'CMakeLists.txt', 'text/plain');
    
    // Download individual mesh files
    exportData.package.meshes.forEach(mesh => {
      this.downloadFile(mesh.content, mesh.filename, 'application/octet-stream');
    });

    console.log(`URDF package exported: ${robotName}`);
    return exportData;
  }

  // Export and send to server
  exportAndSendToServer(scene, robotName = "webxr_robot", options = {}) {
    if (!this.socket) {
      console.warn('No socket connection available for server upload');
      return this.exportAndDownload(scene, robotName, options);
    }

    const exportData = this.exportSceneToUrdf(scene, robotName, options);
    
    // Send to server
    this.socket.emit('urdf-export', {
      robotName,
      urdf: exportData.urdf,
      package: exportData.package,
      timestamp: Date.now(),
      exportType: 'urdf'
    });

    console.log(`URDF package sent to server: ${robotName}`);
    return exportData;
  }

  // Generate URDF XML content
  generateUrdf(scene, robotName, baseLink) {
    let urdf = `<?xml version="1.0"?>\n`;
    urdf += `<robot name="${robotName}">\n\n`;
    
    // Add base link
    urdf += `  <!-- Base link -->\n`;
    urdf += `  <link name="${baseLink}">\n`;
    urdf += `    <visual>\n`;
    urdf += `      <origin xyz="0 0 0" rpy="0 0 0"/>\n`;
    urdf += `      <geometry>\n`;
    urdf += `        <box size="0.1 0.1 0.1"/>\n`;
    urdf += `      </geometry>\n`;
    urdf += `      <material name="base_material">\n`;
    urdf += `        <color rgba="0.5 0.5 0.5 1.0"/>\n`;
    urdf += `      </material>\n`;
    urdf += `    </visual>\n`;
    urdf += `    <collision>\n`;
    urdf += `      <origin xyz="0 0 0" rpy="0 0 0"/>\n`;
    urdf += `      <geometry>\n`;
    urdf += `        <box size="0.1 0.1 0.1"/>\n`;
    urdf += `      </geometry>\n`;
    urdf += `    </collision>\n`;
    urdf += `  </link>\n\n`;

    // Process scene objects
    this.linkCounter = 0;
    this.processSceneObject(scene, urdf, baseLink);

    urdf += `</robot>\n`;
    return urdf;
  }

  // Process scene objects recursively
  processSceneObject(object, urdfContent, parentLink = "base_link") {
    let urdf = urdfContent;

    object.children.forEach(child => {
      if (this.shouldIncludeInUrdf(child)) {
        const linkName = `link_${this.linkCounter++}`;
        const jointName = `joint_${this.linkCounter}`;

        // Add joint
        urdf += `  <!-- Joint connecting ${parentLink} to ${linkName} -->\n`;
        urdf += `  <joint name="${jointName}" type="fixed">\n`;
        urdf += `    <origin xyz="${child.position.x} ${child.position.y} ${child.position.z}" `;
        urdf += `rpy="${child.rotation.x} ${child.rotation.y} ${child.rotation.z}"/>\n`;
        urdf += `    <parent link="${parentLink}"/>\n`;
        urdf += `    <child link="${linkName}"/>\n`;
        urdf += `  </joint>\n\n`;

        // Add link
        urdf += `  <!-- Link ${linkName} -->\n`;
        urdf += `  <link name="${linkName}">\n`;
        
        if (child.geometry) {
          // Visual
          urdf += `    <visual>\n`;
          urdf += `      <origin xyz="0 0 0" rpy="0 0 0"/>\n`;
          urdf += `      <geometry>\n`;
          urdf += this.geometryToUrdf(child.geometry);
          urdf += `      </geometry>\n`;
          if (child.material) {
            urdf += this.materialToUrdf(child.material);
          }
          urdf += `    </visual>\n`;

          // Collision
          urdf += `    <collision>\n`;
          urdf += `      <origin xyz="0 0 0" rpy="0 0 0"/>\n`;
          urdf += `      <geometry>\n`;
          urdf += this.geometryToUrdf(child.geometry);
          urdf += `      </geometry>\n`;
          urdf += `    </collision>\n`;
        }

        urdf += `  </link>\n\n`;

        // Process children recursively
        if (child.children.length > 0) {
          urdf = this.processSceneObject(child, urdf, linkName);
        }
      }
    });

    return urdf;
  }

  // Convert ThreeJS geometry to URDF geometry
  geometryToUrdf(geometry) {
    if (geometry.type === 'BoxGeometry') {
      const params = geometry.parameters;
      return `        <box size="${params.width || 1} ${params.height || 1} ${params.depth || 1}"/>\n`;
    } else if (geometry.type === 'SphereGeometry') {
      const params = geometry.parameters;
      return `        <sphere radius="${params.radius || 0.5}"/>\n`;
    } else if (geometry.type === 'CylinderGeometry') {
      const params = geometry.parameters;
      return `        <cylinder radius="${params.radiusTop || 0.5}" length="${params.height || 1}"/>\n`;
    } else {
      // For complex geometries, export as mesh
      const meshFilename = `mesh_${this.meshCounter++}.stl`;
      return `        <mesh filename="package://meshes/${meshFilename}"/>\n`;
    }
  }

  // Convert ThreeJS material to URDF material
  materialToUrdf(material) {
    let urdf = `      <material name="material_${Date.now()}">\n`;
    
    if (material.color) {
      const color = material.color;
      const alpha = material.opacity !== undefined ? material.opacity : 1.0;
      urdf += `        <color rgba="${color.r} ${color.g} ${color.b} ${alpha}"/>\n`;
    } else {
      urdf += `        <color rgba="0.8 0.8 0.8 1.0"/>\n`;
    }
    
    urdf += `      </material>\n`;
    return urdf;
  }

  // Check if object should be included in URDF
  shouldIncludeInUrdf(object) {
    // Skip certain object types
    const skipTypes = [
      'Light', 'Camera', 'AudioListener', 'Group'
    ];
    
    const skipNames = [
      'controller', 'grip', 'Sphere', 'reticle',
      'Line Group', 'Mesh Group', 'Plane Group', 'Occlusion Group'
    ];

    if (skipTypes.includes(object.type)) return false;
    if (skipNames.some(name => object.name && object.name.toLowerCase().includes(name.toLowerCase()))) return false;
    if (!object.geometry && object.children.length === 0) return false;
    
    return true;
  }

  // Generate package data (package.xml, CMakeLists.txt, meshes)
  generatePackageData(scene, robotName) {
    const packageXml = this.generatePackageXml(robotName);
    const cmakeLists = this.generateCMakeLists(robotName);
    const meshes = this.extractMeshes(scene);

    return {
      packageXml,
      cmakeLists,
      meshes
    };
  }

  // Generate package.xml content
  generatePackageXml(robotName) {
    return `<?xml version="1.0"?>
<package format="2">
  <name>${robotName}</name>
  <version>1.0.0</version>
  <description>URDF model exported from WebXR Mesh Exporter</description>
  
  <maintainer email="user@example.com">WebXR User</maintainer>
  <license>MIT</license>
  
  <buildtool_depend>catkin</buildtool_depend>
  
  <depend>urdf</depend>
  <depend>xacro</depend>
  
  <export>
  </export>
</package>`;
  }

  // Generate CMakeLists.txt content
  generateCMakeLists(robotName) {
    return `cmake_minimum_required(VERSION 3.0.2)
project(${robotName})

find_package(catkin REQUIRED)

catkin_package()

# Install URDF files
install(DIRECTORY urdf/
  DESTINATION \${CATKIN_PACKAGE_SHARE_DESTINATION}/urdf
)

# Install mesh files
install(DIRECTORY meshes/
  DESTINATION \${CATKIN_PACKAGE_SHARE_DESTINATION}/meshes
)
`;
  }

  // Extract meshes from scene for export
  extractMeshes(scene) {
    const meshes = [];
    const extractMeshesRecursive = (object) => {
      if (object.geometry && this.shouldIncludeInUrdf(object)) {
        if (object.geometry.type === 'BufferGeometry' || object.geometry.type === 'Geometry') {
          const stlContent = this.geometryToSTL(object.geometry);
          meshes.push({
            filename: `mesh_${meshes.length}.stl`,
            content: stlContent
          });
        }
      }
      
      object.children.forEach(child => extractMeshesRecursive(child));
    };

    extractMeshesRecursive(scene);
    return meshes;
  }

  // Convert geometry to STL format
  geometryToSTL(geometry) {
    let stl = 'solid mesh\n';
    
    if (geometry.attributes && geometry.attributes.position) {
      const positions = geometry.attributes.position.array;
      const normals = geometry.attributes.normal ? geometry.attributes.normal.array : null;
      
      for (let i = 0; i < positions.length; i += 9) {
        stl += 'facet normal ';
        if (normals) {
          stl += `${normals[i/3]} ${normals[i/3 + 1]} ${normals[i/3 + 2]}\n`;
        } else {
          stl += '0 0 1\n';
        }
        stl += 'outer loop\n';
        stl += `vertex ${positions[i]} ${positions[i+1]} ${positions[i+2]}\n`;
        stl += `vertex ${positions[i+3]} ${positions[i+4]} ${positions[i+5]}\n`;
        stl += `vertex ${positions[i+6]} ${positions[i+7]} ${positions[i+8]}\n`;
        stl += 'endloop\n';
        stl += 'endfacet\n';
      }
    }
    
    stl += 'endsolid mesh\n';
    return stl;
  }

  // Helper methods for scene cleaning
  removeControllers(scene) {
    const toRemove = [];
    scene.traverse(child => {
      if (child.name && (
        child.name.includes('controller') ||
        child.name.includes('grip') ||
        child.name.includes('Controller')
      )) {
        toRemove.push(child);
      }
    });
    toRemove.forEach(obj => {
      if (obj.parent) obj.parent.remove(obj);
    });
  }

  removeBalls(scene) {
    const toRemove = [];
    scene.traverse(child => {
      if (child.geometry && child.geometry.type === 'IcosahedronGeometry') {
        toRemove.push(child);
      }
    });
    toRemove.forEach(obj => {
      if (obj.parent) obj.parent.remove(obj);
    });
  }

  removeUIElements(scene) {
    const toRemove = [];
    scene.traverse(child => {
      if (child.name && (
        child.name.includes('reticle') ||
        child.name.includes('Reticle') ||
        child.name.includes('UI')
      )) {
        toRemove.push(child);
      }
    });
    toRemove.forEach(obj => {
      if (obj.parent) obj.parent.remove(obj);
    });
  }

  // Clone scene (simplified version)
  cloneScene(scene) {
    return scene.clone(true);
  }

  // Download file helper
  downloadFile(content, filename, mimeType) {
    const blob = new Blob([content], { type: mimeType });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
    URL.revokeObjectURL(link.href);
  }

  // Add export button to UI
  addExportButton(container = document.body, scene, options = {}) {
    const button = document.createElement('button');
    button.textContent = 'Export to URDF';
    button.style.position = 'absolute';
    button.style.top = '120px';
    button.style.right = '20px';
    button.style.padding = '10px 20px';
    button.style.backgroundColor = '#4CAF50';
    button.style.color = 'white';
    button.style.border = 'none';
    button.style.borderRadius = '5px';
    button.style.cursor = 'pointer';
    button.style.fontSize = '14px';
    button.style.zIndex = '1000';

    button.addEventListener('click', () => {
      const robotName = prompt('Enter robot name:', 'webxr_robot') || 'webxr_robot';
      
      if (this.socket) {
        this.exportAndSendToServer(scene, robotName, options);
      } else {
        this.exportAndDownload(scene, robotName, options);
      }
    });

    container.appendChild(button);
    return button;
  }
}

export default UrdfExporter;
