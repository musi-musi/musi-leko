#include "glad/glad.h"
#include "glfw3.h"
#include "stb_image.h"

#include "cimgui.h"

int imgui_glfw_init(GLFWwindow* window, int install_callbacks);
void imgui_glfw_shutdown();
void imgui_glfw_frame();

int imgui_gl_init();
void imgui_gl_shutdown();
void imgui_gl_frame();
void imgui_gl_render(ImDrawData* draw_data);