set(RUST_PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust")
set(RUST_TARGET_DIR "${RUST_PROJECT_DIR}/target")

# Check if Flutter is building in Debug or Release/Profile mode
if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(CARGO_CMD cargo build)
    set(RUST_OUT_DIR "debug")
else()
    set(CARGO_CMD cargo build --release)
    set(RUST_OUT_DIR "release")
endif()

set(HUNSPELL_DLL "${RUST_TARGET_DIR}/${RUST_OUT_DIR}/hunspell_backend.dll")

add_custom_command(
  OUTPUT "${HUNSPELL_DLL}"
  COMMAND ${CARGO_CMD}
  WORKING_DIRECTORY "${RUST_PROJECT_DIR}"
  COMMENT "Compiling Rust backend..."
)

add_custom_target(hunspell_backend_target ALL DEPENDS "${HUNSPELL_DLL}")

set_target_properties(${PLUGIN_NAME} PROPERTIES
  IMPORTED_LOCATION_RELEASE "${HUNSPELL_DLL}"
  IMPORTED_LOCATION_DEBUG "${HUNSPELL_DLL}"
  IMPORTED_LOCATION_PROFILE "${HUNSPELL_DLL}"
)

install(FILES "${HUNSPELL_DLL}" DESTINATION "${CMAKE_INSTALL_PREFIX}")
