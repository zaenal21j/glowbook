// Load all Stimulus controllers under app/javascript/controllers
import { application } from "controllers/application"
import ChatController from "controllers/chat_controller"
import NearbySearchController from "controllers/nearby_search_controller"

application.register("chat", ChatController)
application.register("nearby-search", NearbySearchController)

// Eager-load controllers registered via comment annotations:
// import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
// eagerLoadControllersFrom("controllers", application)
