import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="img-preview"
export default class extends Controller {
  static targets = ["select", "image"]

  connect() {
    console.log("img_preview controller connected!")
    // Set initial image on load if there's a selected value.
    this.updatePreview
  }

  updatePreview() {
    const selectedValue = this.selectTarget.value

    // `selectedValue` checks if the variable exists and is "truthy" (not null, undefined, false, 0, or empty string)
    // `&& selectedValue !== ""` also checks if the value is NOT an empty string
    // The first check prevents errors if `selectedValue` is null/undefined, and the second ensures there's actually a selection made (not just the "Select a cocktail image" prompt option).
    if (selectedValue && selectedValue !== "") {
      this.imageTarget.src = `/assets/${selectedValue}`
      // Use `d-none` if using Bootstrap.
      this.imageTarget.classList.remove("d-none")
    } else {
      this.imageTarget.classList.add("d-none")
    }
  }
}
