// Load all Stimulus controllers under app/javascript/controllers
import { application } from "controllers/application"
import ChatController from "controllers/chat_controller"
import NearbySearchController from "controllers/nearby_search_controller"
import DropdownController from "controllers/dropdown_controller"
import DismissableController from "controllers/dismissable_controller"

application.register("chat", ChatController)
application.register("nearby-search", NearbySearchController)
application.register("dropdown", DropdownController)
application.register("mobile-menu", DropdownController)
application.register("dismissable", DismissableController)

// Eager-load controllers registered via comment annotations:
// import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
// eagerLoadControllersFrom("controllers", application)
