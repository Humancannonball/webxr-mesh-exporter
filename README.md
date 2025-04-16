# WebXR Mesh and Plane Export Tool

A web-based application that allows users to interact with an augmented reality environment, shoot physics-based balls, and export 3D mesh data of the environment. This tool is particularly designed for Meta Quest VR headsets to capture room layout and furniture.

## Overview

This application uses WebXR technology to detect and render the physical environment (walls, furniture) in virtual space. Users can interact with the environment by shooting physics-based balls and can export the detected 3D mesh data for use in other applications.

## Key Features

- **AR/VR Environment Mapping**: Detects and visualizes physical spaces (walls, floors, furniture) in VR
- **Physics Interactions**: Shoot balls that interact with the detected environment
- **Mesh Export**: Export detected meshes as JSON or STL for use in other 3D applications
- **Multi-user Support**: Built-in socket.io implementation for potential multi-user experiences
- **Works with Various Quest Headsets**: 
  - Quest 1: Wall detection
  - Quest 2/Pro: Wall and furniture detection
  - Quest 3: Full mesh detection

## Technologies Used

- **Three.js**: Core 3D rendering library
- **WebXR**: For AR/VR immersive experiences
- **Rapier Physics**: For realistic physics simulations
- **Socket.io**: For real-time communication (multi-user capability)
- **Express.js**: Backend server framework

## Project Structure

- `index.html`: Main entry point and HTML structure
- `style.css`: Styling for UI elements
- `client.js`: Main client-side application logic including WebXR, Three.js setup, and physics
- `server.js`: Socket.io server for multi-user functionality
- `ARButton.js`: Custom WebXR button implementation for AR sessions
- `RapierPhysics.js`: Physics implementation using Rapier

## File Descriptions

*   **`index.html`**: The main HTML file that structures the web page. It includes metadata, links the CSS stylesheet, sets up the import map for Three.js modules, and loads the main client-side JavaScript (`client.js`). It also contains initial instructions shown before the AR session starts.
*   **`style.css`**: Contains CSS rules for styling the HTML elements, including the loading screen and the AR/VR buttons.
*   **`client.js`**: The core client-side logic. It handles:
    *   Setting up the Three.js scene, camera, lights, and renderer.
    *   Initializing the WebXR session and handling AR features like plane detection, mesh detection, and hit-testing.
    *   Setting up user interactions, controller inputs (including button presses for shooting balls and exporting).
    *   Integrating the Rapier physics engine for ball interactions.
    *   Managing the scene graph, adding/removing objects.
    *   Communicating with the server via Socket.IO for multi-user state and file saving.
    *   Implementing the JSON and STL export functionalities.
*   **`server.js`**: The Node.js backend server using Express and Socket.IO. It handles:
    *   Serving the static files (HTML, CSS, client-side JS).
    *   Managing WebSocket connections for real-time communication between clients (though multi-user features seem basic currently).
    *   Receiving file data (JSON/STL) from clients via Socket.IO and saving it to the server's file system in the `export/json` and `export/stl` directories.
*   **`ARButton.js`**: A helper script (likely adapted from Three.js examples) that creates and manages the "START AR" / "STOP AR" button, handling the process of requesting and ending a WebXR 'immersive-ar' session.
*   **`package.json`**: Defines the project's metadata, dependencies (Express, Socket.IO, Three.js), and scripts (like the `start` script to run the server).

## Key Components

### WebXR Implementation
The app uses the WebXR API to access AR/VR capabilities, including:
- Plane detection
- Mesh detection
- Hit testing
- Controller input

### Physics
Uses Rapier physics engine (via CDN) for realistic ball physics and interactions with detected meshes.

### Mesh Detection and Export
The app can:
1. Detect physical objects in the environment
2. Create 3D mesh representations
3. Allow export of the detected environment as JSON or STL:
   - JSON: For use with Three.js and related tools
   - STL: For 3D printing or import into CAD software

## Setup and Running Locally

### Prerequisites
- Node.js and npm installed
- A WebXR-compatible browser
- For full functionality: Meta Quest headset connected to your computer

### Installation

1. Clone the repository
```bash
git clone https://github.com/yourusername/jasonharron.github.io.git
cd jasonharron.github.io
```

2. Install dependencies
```bash
npm install
```

3. Start the server
```bash
npm start
```

4. Access the application
Open a browser and navigate to `http://localhost:3000`

### Using ngrok for Remote Access During Development

To make your local development server accessible from other devices (like a VR headset) over the internet:

1. Install ngrok
```bash
npm install -g ngrok
# or download from https://ngrok.com/download
```

2. Start your local server as normal
```bash
npm start
```

3. In a separate terminal, start ngrok pointing to your local server port
```bash
ngrok http 3000
```

4. Ngrok will provide a public URL (like `https://abc123.ngrok.io`)

5. Access this URL from your Quest headset browser to test the application remotely

Note: The free version of ngrok will assign a new URL each time you restart it. For consistent URLs, consider a paid ngrok plan.

### VR/AR Mode

To use in VR/AR mode:
1. Ensure your Quest headset is connected to your computer or access your ngrok URL
2. Access the application in your browser
3. Click the "START AR" button
4. Follow the on-screen instructions for setup

## Controls

- **Trigger Buttons**: Shoot physics balls
- **X Button**: Toggle visibility of detected room
- **Y Button**: Export room data as JSON
- **B Button**: Export room data as STL
- **Thumbsticks**: Navigation (when in calibration mode)

## Development Notes

- The application uses feature detection to determine what XR features are available
- The socket.io implementation allows for future multi-user experiences
- Exported files are saved both to your device's download folder and to the server in:
  - `export/json/` directory for JSON files
  - `export/stl/` directory for STL files
- The exported JSON can be loaded into Three.js Editor or other compatible 3D applications
- The exported STL can be used for 3D printing or in CAD software
