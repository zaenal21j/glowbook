// Load all Stimulus controllers under app/javascript/controllers
import { application } from "controllers/application"
import ChatController from "controllers/chat_controller"

application.register("chat", ChatController)

// Eager-load controllers registered via comment annotations:
// import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
// eagerLoadControllersFrom("controllers", application)
