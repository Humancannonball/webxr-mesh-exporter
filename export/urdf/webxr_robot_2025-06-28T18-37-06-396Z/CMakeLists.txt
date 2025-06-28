cmake_minimum_required(VERSION 3.0.2)
project(webxr_robot)

find_package(catkin REQUIRED)

catkin_package()

# Install URDF files
install(DIRECTORY urdf/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/urdf
)

# Install mesh files
install(DIRECTORY meshes/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/meshes
)
