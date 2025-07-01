const express = require("express");
const app = express();
const path = require("path");
const http = require("http");
const fs = require("fs");
const server = http.createServer(app);
const { Server } = require("socket.io");
const io = new Server(server, {
  cors: {
    origin: process.env.NODE_ENV === 'production' ? false : ["http://localhost:3000", "http://127.0.0.1:3000"],
    methods: ["GET", "POST"]
  }
});

// Environment configuration
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

let clock = Date.now();

// Middleware for security and parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Serve static files
app.use(express.static(path.join(__dirname, "public")));

// Security headers for production
if (NODE_ENV === 'production') {
  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
  });
}

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Health check endpoint for AWS
app.get("/health", (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: NODE_ENV
  });
});

let clients = 0; //Count the number of users connected to the server
let userArray = [];
let planeArray = [];
let meshArray = [];

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

  socket.on("sceneExport", function (data) {
    console.log("Received scene export from client:", socket.id);
    console.log("Export timestamp:", new Date(data.timestamp).toISOString());
    console.log("Scene data size:", data.sceneData.length, "characters");
    
    // Create exports directory if it doesn't exist
    const exportsDir = path.join(__dirname, '..', 'data', 'export', 'json');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }
    
    // Create filename with timestamp and client ID
    const timestamp = new Date(data.timestamp).toISOString().replace(/[:.]/g, '-');
    const clientId = socket.id.substring(0, 8); // Use first 8 chars of socket ID
    const sceneFilename = `scene_${timestamp}_${clientId}.json`;
    const refSpaceFilename = `referenceSpace_${timestamp}_${clientId}.json`;
    
    try {
      // Save scene data to file
      const sceneFilePath = path.join(exportsDir, sceneFilename);
      fs.writeFileSync(sceneFilePath, data.sceneData, 'utf8');
      console.log("Scene saved to:", sceneFilePath);
      
      // Save reference space data if it exists
      if (data.referenceSpace) {
        const refSpaceFilePath = path.join(exportsDir, refSpaceFilename);
        fs.writeFileSync(refSpaceFilePath, data.referenceSpace, 'utf8');
        console.log("Reference space saved to:", refSpaceFilePath);
      }
      
      // Optionally broadcast to other clients that a scene was exported
      socket.broadcast.emit("sceneExportNotification", {
        clientId: socket.id,
        timestamp: data.timestamp,
        filename: sceneFilename
      });
    } catch (error) {
      console.error("Error saving scene export:", error);
      socket.emit("sceneExportError", { message: "Failed to save scene export" });
    }
  });
});

//////////////////////////////////
//  Listen to the socket port  //
////////////////////////////////

server.listen(PORT, () => {
  console.log(`Mixed Reality Robot Programming Platform listening on port ${PORT}`);
  console.log(`Environment: ${NODE_ENV}`);
  console.log(`Server started at: ${new Date().toISOString()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
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

