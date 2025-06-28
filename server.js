const express = require("express");
const app = express();
const path = require("path");
const http = require("http");
const server = http.createServer(app);
const { Server } = require("socket.io");
const io = new Server(server);
const fs = require('fs').promises;

let clock = Date.now();

app.use(express.static(__dirname + "/"));

app.get("/", (req, res) => {
  res.sendFile(__dirname + "/index.html");
});

let clients = 0; //Count the number of users connected to the server
let userArray = [];
let planeArray = [];
let meshArray = [];

// Ensure export directories exist
async function ensureExportDirs() {
  try {
    await fs.mkdir(path.join(__dirname, 'export'), { recursive: true });
    await fs.mkdir(path.join(__dirname, 'export/json'), { recursive: true });
    await fs.mkdir(path.join(__dirname, 'export/stl'), { recursive: true });
    await fs.mkdir(path.join(__dirname, 'export/urdf'), { recursive: true });
  } catch (error) {
    console.error('Error creating export directories:', error);
  }
}

// Initialize export directories
ensureExportDirs();

////////////////////////
// Socket Connection //
//////////////////////

io.sockets.on("connection", (socket) => {
  clients += 1; //Add one client to the server count

  //To client who just connected
  //socket.emit("mySocketID", socket.id); //Sends socket.id to client as mySocketID
  //socket.emit("userArrayFromServer", userArray); //Server sends userArray to client who just connected

  //Adds new user to server after existing userArray has been sent to client
  socket.userData = {
    id: socket.id,
    color: 0,
    presenting: 0,
    ar: 0,
    vr: 0,
    xr: 0,
    controllerNum: 0,
    con1: 0,
    con2: 0,
    posX: 0,
    posY: 0,
    posZ: 0,
  }; //Default values;
  addToUserArray(socket.userData);
  console.log("The userArray now has " + userArray.length + " objects");

  //To all other existing clients
  socket.emit("addNewUser", socket.userData); //Sends information back to the client who is connecting
  socket.broadcast.emit("addNewUser", socket.userData); //Sends new client information to all other clients

  //Send server clock to the new client
  var timeNow = Date.now() - clock;
  socket.emit("serverTime", timeNow);

  //Log Information to the Server Console
  connectionLog(socket.id, clients); //Logs new connection to the server console
  timeLog(); //Logs the amount of time the server has been running

  if (planeArray.length > 0) {
    for (let i = 0; i < planeArray.length; i++) {
      socket.emit("addPlaneToClient", planeArray[i]);
    }
  }
  if (meshArray.length > 0) {
    for (let i = 0; i < meshArray.length; i++) {
      socket.emit("addMesh-detectedFromServer", meshArray[i]);
    }
  }

  ////////////////////////
  // Socket disconnect //
  //////////////////////

  socket.on("disconnect", function () {
    clients -= 1;
    userArray = userArray.filter((e) => e !== socket.id);
    //socket.broadcast.emit("isPresentingArrayFilter", socket.id);
    var newArray = [];
    var con1 = "controller1";
    var con2 = "controller2";
    var data = socket.id;
    var dataCon1 = data.concat(con1);
    var dataCon2 = data.concat(con2);
    console.log(data);
    console.log(dataCon1);
    console.log(dataCon2);
    for (let i = 0; i < userArray.length; i++) {
      if (
        userArray[i].id !== data &&
        userArray[i].id !== dataCon1 &&
        userArray[i].id !== dataCon2
      ) {
        newArray.push(userArray[i]);
      } else if (userArray[i].id !== data) {
        // newArray.push(isPresentingArray[i]);
      }
    }
    userArray = newArray;

    console.log(
      `${socket.id} disconnected. There are ` + clients + " users online."
    );
    socket.broadcast.emit("deleteUser", socket.id);
  });

  ////////////////////////////////
  // Other custom socket calls //
  //////////////////////////////

  socket.on("addControllerToServer", function (data) {
    socket.broadcast.emit("addControllerToClient", data);
    data.presenting = 1;
    addToUserArray(data);
    console.log("Controller " + data.id + " has entered XR.");
    console.log(userArray.length);
  });

  socket.on("addCubeToServer", function (data) {
    socket.broadcast.emit("addCubeToClient", data);
    let i = getIndexByID(data); //calls custom function
    data.presenting = 1;
    userArray[i] = data;
    console.log("Client " + data.id + " has entered XR.");
    console.log(userArray.length);
  });

  socket.on("addPlane", function (data) {
    socket.broadcast.emit("addPlaneToClient", data);
    //planeArray.push(data);
  });

  socket.on("ballShot", function (data) {
    socket.broadcast.emit("ballsFromServer", data);
  });

  socket.on("debug", function (data) {
    console.log("debug");
    console.log(data);
    socket.broadcast.emit("debugFromServer", data);
  });

  socket.on("requestUserArrayFromServer", function () {
    //console.log(userArray);
    socket.emit("sendUserArrayToClient", userArray);
  });
  socket.on("requestUserArrayFromServerDebug", function () {
    socket.emit("sendUserArrayToClientDebug", userArray);
  });
  socket.on("stoppedPresenting", function (data) {
    console.log("Client " + data + " stoppedPresenting");
    socket.broadcast.emit("stoppedPresentingUserArray", data);
    socket.emit("stoppedPresentingUserArray", data);

    // Change presenting value to 0

    var newArray = [];
    var con1 = "controller1";
    var con2 = "controller2";
    var dataCon1 = data.concat(con1);
    var dataCon2 = data.concat(con2);
    for (let i = 0; i < userArray.length; i++) {
      if (
        userArray[i].id == data ||
        userArray[i].id == dataCon1 ||
        userArray[i].id == dataCon2
      ) {
        userArray[i].presenting = 0;
      }
    }

    //Remove controllers from the userArray
    userArray = userArray.filter((e) => e !== dataCon1);
    userArray = userArray.filter((e) => e !== dataCon2);
    //socket.broadcast.emit("isPresentingArrayFilter", socket.id);
    newArray = [];
    for (let i = 0; i < userArray.length; i++) {
      if (userArray[i].id !== dataCon1 && userArray[i].id !== dataCon2) {
        newArray.push(userArray[i]);
      } else if (userArray[i].id !== data) {
        // newArray.push(isPresentingArray[i]);
      }
    }
    userArray = newArray;
  });

  socket.on("syncXRSupport", function (data) {
    console.log(data);
    let i = getIndexByID(data); //calls custom function
    userArray[i] = data;
  });

  socket.on("updatePos", function (data) {
    socket.broadcast.emit("updatePosFromServer", data);
  });

  socket.on("addMesh-detected", function (data) {
    socket.broadcast.emit("addMesh-detectedFromServer", data);
    //meshArray.push(data);
  });

  // Handle URDF export from client
  socket.on("urdf-export", async function (data) {
    console.log(`Received URDF export from ${socket.id}: ${data.robotName}`);
    
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const exportDir = path.join(__dirname, 'export/urdf', `${data.robotName}_${timestamp}`);
      
      // Create robot-specific directory
      await fs.mkdir(exportDir, { recursive: true });
      await fs.mkdir(path.join(exportDir, 'urdf'), { recursive: true });
      await fs.mkdir(path.join(exportDir, 'meshes'), { recursive: true });
      
      // Save URDF file
      await fs.writeFile(
        path.join(exportDir, 'urdf', `${data.robotName}.urdf`), 
        data.urdf, 
        'utf8'
      );
      
      // Save package.xml
      await fs.writeFile(
        path.join(exportDir, 'package.xml'), 
        data.package.packageXml, 
        'utf8'
      );
      
      // Save CMakeLists.txt
      await fs.writeFile(
        path.join(exportDir, 'CMakeLists.txt'), 
        data.package.cmakeLists, 
        'utf8'
      );
      
      // Save mesh files
      for (const mesh of data.package.meshes) {
        await fs.writeFile(
          path.join(exportDir, 'meshes', mesh.filename), 
          mesh.content, 
          'utf8'
        );
      }
      
      console.log(`URDF package saved: ${exportDir}`);
      
      // Notify client of successful save
      socket.emit("urdf-export-complete", {
        success: true,
        robotName: data.robotName,
        exportPath: exportDir,
        timestamp: data.timestamp
      });
      
    } catch (error) {
      console.error('Error saving URDF export:', error);
      socket.emit("urdf-export-complete", {
        success: false,
        error: error.message,
        robotName: data.robotName,
        timestamp: data.timestamp
      });
    }
  });

  // Handle JSON scene export
  socket.on("scene-export", async function (data) {
    console.log(`Received scene export from ${socket.id}`);
    
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `scene_${timestamp}.json`;
      const filePath = path.join(__dirname, 'export/json', filename);
      
      await fs.writeFile(filePath, JSON.stringify(data.scene, null, 2), 'utf8');
      
      if (data.referenceSpace) {
        const refFilename = `reference_space_${timestamp}.json`;
        const refFilePath = path.join(__dirname, 'export/json', refFilename);
        await fs.writeFile(refFilePath, JSON.stringify(data.referenceSpace, null, 2), 'utf8');
      }
      
      console.log(`Scene exported: ${filePath}`);
      
      socket.emit("scene-export-complete", {
        success: true,
        filename: filename,
        timestamp: timestamp
      });
      
    } catch (error) {
      console.error('Error saving scene export:', error);
      socket.emit("scene-export-complete", {
        success: false,
        error: error.message
      });
    }
  });
});

//////////////////////////////////
//  Listen to the socket port  //
////////////////////////////////

server.listen(3000, () => {
  console.log("listening on *:3000");
});

/////////////////////////
//  Custom functions  //
///////////////////////

function addToUserArray(JSON) {
  userArray.push(JSON);
}

function connectionLog(id, num) {
  if (clients == 1) {
    console.log(`${id} connected. There is ` + num + " client online.");
  } else {
    console.log(`${id} connected. There are ` + num + " clients online.");
  }
}

function disconnectionLog(id, num) {
  if (clients == 1) {
    console.log(`${id} disconnected. There is ` + num + " client online.");
  } else {
    console.log(`${id} disconnected. There are ` + num + " clients online.");
  }
}

function getIndexByID(data) {
  for (let i in userArray) {
    if (userArray[i].id == data.id) {
      return i;
    }
  }
}

function timeLog() {
  console.log(
    "The server has been running for " +
      (Date.now() - clock) / 1000 +
      " seconds."
  );
}

