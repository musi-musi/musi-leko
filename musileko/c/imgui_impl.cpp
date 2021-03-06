#include "imgui.h"
#include "imgui_impl_glfw.h"
#include "imgui_impl_opengl3.h"

extern "C" {

    #include "imgui_impl.h"

    int imgui_glfw_init(GLFWwindow* window, int install_callbacks) {
        return ImGui_ImplGlfw_InitForOpenGL(window, install_callbacks != 0) ? 1 : 0;
    }
    void imgui_glfw_shutdown() {
        ImGui_ImplGlfw_Shutdown();
    }
    void imgui_glfw_frame() {
        ImGui_ImplGlfw_NewFrame();
    }

    void imgui_glfw_set_io_enabled(bool enabled) {
        ImGui_ImpleGlfw_SetIOEnabled(enabled);
    }

    int imgui_gl_init() {
        return ImGui_ImplOpenGL3_Init(NULL) ? 1 : 0;
    }
    void imgui_gl_shutdown() {
        ImGui_ImplOpenGL3_Shutdown();
    }
    void imgui_gl_frame() {
        ImGui_ImplOpenGL3_NewFrame();
    }
    void imgui_gl_render(ImDrawData* draw_data) {
        ImGui_ImplOpenGL3_RenderDrawData(draw_data);
    }
}