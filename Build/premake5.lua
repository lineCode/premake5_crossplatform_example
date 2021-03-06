-- Premake5 Wiki: https://github.com/premake/premake-core/wiki


local ROOT = "../"    -- Path to project root


-----------------------------------
-- WORKSPACE CONFIGURATIONS
-----------------------------------
workspace "Premake_CrossCompile"
  configurations { "Debug", "Release"}
  platforms { "x64", "x32" }
  location( ROOT .. "project_" .. _ACTION)

  project "GLFW_Triangle"
    targetname "glfw_triangle"    -- Name of executable
    kind "WindowedApp"            -- (WindowedApp, ConsoleApp, etc)
    language   "C++"


-----------------------------------
-- COMPILER/LINKER CONFIGURATIONS
-----------------------------------
    
	flags "FatalWarnings"         -- All warnings on.

    filter { "platforms:*32" }
      architecture "x86"
    filter { "platforms:*64" }
      architecture "x64"
      
    filter { "configurations:Debug" }
      defines { "DEBUG" }
      flags { "Symbols" }
    filter { "configurations:Release" }
      defines { "NDEBUG" }
      optimize "On"

    filter {} -- reset filter

	
-----------------------------------
-- BUILD CONFIGURATIONS
-----------------------------------
    local cur_toolset = "default" -- workaround for premake issue #257
                                 -- 
    filter {"system:macosx"}           -- Mac uses clang.
      toolset "clang"
      cur_toolset = "clang"

    filter { "action:gmake" }
      buildoptions { "-std=c++14" }

    -- Set the rpath on the executable, to allow for relative path for dynamic lib
    filter { "system:macosx" }
      if cur_toolset == "clang" or cur_toolset == "gcc" then  -- issue #257
        linkoptions { "-rpath @executable_path/lib" }
      end
      
    filter {} -- clear filter 	
	

-----------------------------------
-- FILE PATH CONFIGURATIONS
-----------------------------------
    local output_dir_root         = ROOT .. "bin_%{cfg.platform}_%{cfg.buildcfg}"
    targetdir(output_dir_root)    -- Where all output files are stored
    local output_dir_lib          = output_dir_root .. "/libs" -- Mac Specific

    local source_dir_root         = ROOT .. "Source"
    local source_dir_engine       = source_dir_root .. "/Engine"
    local source_dir_dependencies = source_dir_root .. "/Dependencies"

    local source_dir_includes     = source_dir_dependencies .. "/**/Includes"
    local source_dir_libs         = source_dir_dependencies .. "/**/" .. "Libs_" .. os.get()
    -- optional for libs that are 32 or 64 bit specific
    local source_dir_libs32       = source_dir_libs .. "/lib_x32"
    local source_dir_libs64       = source_dir_libs .. "/lib_x64"


    -- Files to be compiled (cpp) or added to project (visual studio)
    files
    {
      source_dir_engine .. "/**.cpp",
      source_dir_engine .. "/**.hpp"
    }

    -- Ignore files for other operating systems (not necessary in this project)
    filter { "system:macosx" }  removefiles { source_dir_engine .. "/**_windows.*" }
    filter { "system:windows" } removefiles { source_dir_engine .. "/**_macosx.*"  }
    filter {} -- reset filter


    -- TODO: add 'vpaths' to organize filters in visual studio.


    -- Where compiler should look for library includes
    -- NOTE: for library headers always use  '#include <LIB/lib.hpp>' not quotes
    includedirs
    {
      source_dir_includes
    }
    

    -- Where linker should look for library files
    -- NOTE: currently each library must have "LIBS_<OS>" in its path.
    libdirs
    {
      source_dir_libs,                                           -- default: look for any libs here (does not recurse)
      source_dir_libs .. "/lib_%{cfg.platform}",                 -- libs with ONLY x32/x64 (no Release/Debug) versions
      source_dir_libs .. "/%{cfg.buildcfg}",                     -- libs with ONLY Release/Debug (no x32/x64) versions
      source_dir_libs .. "/%{cfg.buildcfg}/lib_%{cfg.platform}", -- libs with BOTH Release/Debug AND x32/x64 versions
      source_dir_libs .. "/lib_%{cfg.platform}/%{cfg.buildcfg}"  -- libs with BOTH x32/x64 AND Release/Debug versions (order reversed)
    }

    
    -- OS-specific Libraries - Dynamic libs will need to be copied to output

    filter { "system:windows" }  -- Currently all static libs; No copying
      links
      {
        "glew32s",               -- static lib
        "glu32",                 -- Windows-specific for GLEW
        "glfw3",                 -- static lib
        "opengl32",
      }
    filter { "system:macosx" }   -- Currently all dylibs; Copy in postbuild
      links
      {
        "GLEW",
        "glfw3",
        "X11.6",                 -- Mac-specific for GLFW
        "pthread",               -- Mac-specific for GLFW
        "Xrandr.2",              -- Mac-specific for GLFW
        "Xi.6",                  -- Mac-specific for GLFW
        "Cocoa.framework",       -- Mac-specific for GLFW
        "IOKit.framework",       -- Mac-specific for GLFW
        "CoreVideo.framework",   -- Mac-specific for GLFW
        "OpenGL.framework",
      }
    filter {}


-----------------------------------
-- POST-BUILD CONFIGURATIONS
-----------------------------------
    -- Setting up cross-platform file manipulation commands
    -- NOTE: this is what premake5's tokens -should- before, but see issue #280
    local CWD       = "cd " .. os.getcwd() .. "; " -- We are in current working directory
    local MKDIR     = "mkdir -p "
    local COPY      = "cp -rf "

    local SEPARATOR = "/"

    if(os.get() == "windows") then
      CWD      = "chdir " .. os.getcwd() .. " && "
      MKDIR     = "mkdir "
      COPY      = "xcopy /Q /E /Y /I "
      SEPARATOR = "\\"
    end

    -- mac copies dylibs to output dir
    filter { "system:macosx" }
      postbuildcommands
      {
        path.translate ( CWD .. MKDIR .. output_dir_lib, SEPARATOR ),
        path.translate ( CWD .. COPY .. source_dir_dependencies .. "/*/Libs_macosx/*.dylib " .. output_dir_lib, SEPARATOR )
      }

    -- windows copies dll's to output dir (currently not used)
    filter { "system:windows" }
      postbuildcommands
      {
	    -- TODO: need  to re-write for wildcard file selection on windows...
        -- path.translate ( CWD .. COPY .. source_dir_dependencies .. "/*/Libs_windows/*.dll " .. output_dir_root , SEPARATOR )
      }

    -- Copying resource files to output dir (currently not used)
    -- postbuildcommands
    -- {
    --   path.translate ( CWD .. COPY .. <RESOURCE_PATH> .. "/* " .. output_dir_root , SEPARATOR )
    -- }
