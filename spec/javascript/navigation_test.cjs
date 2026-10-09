const assert = require("node:assert/strict")
const { test } = require("node:test")
const { readFileSync } = require("node:fs")
const { resolve } = require("node:path")
const vm = require("node:vm")

function controller(filename) {
  const source = readFileSync(resolve(__dirname, `../../app/javascript/controllers/${filename}`), "utf8")
    .replace(/^import .*$/gm, "")
    .replace("export default class", "ControllerClass = class")
  const context = { Controller: class {} }
  vm.runInNewContext(source, context)
  return new context.ControllerClass()
}

function menu() {
  const instance = controller("dropdown_controller.js")
  const classes = new Set()
  const button = { attributes: {}, focusCount: 0, setAttribute(k, v) { this.attributes[k] = v }, focus() { this.focusCount++ }, contains(target) { return target === this } }
  const panel = { contains(target) { return target === this }, classList: {
    contains(name) { return classes.has(name) },
    add(name) { classes.add(name) },
    toggle(name, add) { if (add) classes.add(name); else classes.delete(name) }
  } }
  instance.buttonTarget = button
  instance.menuTarget = panel
  instance.connect()
  return { instance, button, panel }
}

test("menus start closed and expose their expanded state", () => {
  const { instance, button, panel } = menu()
  assert.equal(panel.classList.contains("hidden"), true)
  assert.equal(button.attributes["aria-expanded"], "false")
  instance.toggle()
  assert.equal(panel.classList.contains("hidden"), false)
  assert.equal(button.attributes["aria-expanded"], "true")
  instance.toggle()
  assert.equal(panel.classList.contains("hidden"), true)
})

test("clicking outside closes a menu without moving focus", () => {
  const { instance, button, panel } = menu()
  instance.toggle()
  instance.closeOutside({ target: {} })
  assert.equal(panel.classList.contains("hidden"), true)
  assert.equal(button.focusCount, 0)
})

test("clicking the menu or its toggle does not trigger outside dismissal", () => {
  const { instance, button, panel } = menu()
  instance.toggle()
  instance.closeOutside({ target: button })
  instance.closeOutside({ target: panel })
  assert.equal(panel.classList.contains("hidden"), false)
})

test("Escape closes an open menu and returns focus to its toggle", () => {
  const { instance, button, panel } = menu()
  instance.toggle()
  instance.closeOnEscape()
  assert.equal(panel.classList.contains("hidden"), true)
  assert.equal(button.focusCount, 1)
  instance.closeOnEscape()
  assert.equal(button.focusCount, 1)
})

test("reconnecting a cached page closes a previously open menu", () => {
  const { instance, button, panel } = menu()
  instance.toggle()
  instance.connect()
  assert.equal(panel.classList.contains("hidden"), true)
  assert.equal(button.attributes["aria-expanded"], "false")
})

test("dismiss removes only its bound message", () => {
  const instance = controller("dismissable_controller.js")
  let removed = false
  instance.element = { remove() { removed = true } }
  instance.dismiss()
  assert.equal(removed, true)
})
