import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-preview"
export default class extends Controller {
  static targets = ["input", "image", "container"]

  connect() {
    console.log("file_preview controller connected!")
  }

  preview() {
    // Get the first file from the file input's FileList
    // this.inputTarget.files returns a FileList (array-like) of all selected files
    // [0] accesses the first file since we're not using multiple file upload
    const file = this.inputTarget.files[0]

    // Check TWO conditions before proceeding:
    // 1. "file" exists (user actually selected a file)
    // 2. The file's MIME type starts with "image/" (it's actually an image file like image/jpeg, image/png, etc.)
    if (file && file.type.startsWith("image/")) {

      // Create a new FileReader instance
      // FileReader is a built-in browser API that reads files from the user's computer
      const reader = new FileReader()

      // Set up an event handler that fires AFTER the file has been successfully read
      // This is asynchronous - it won't run immediately, but when reading completes
      // "event" is the load event object
      reader.onload = (event) => {

        // event.target is the FileReader itself
        // event.target.result contains the base64-encoded data URL of the image
        // Set this data URL as the src of your image element to display the preview
        this.imageTarget.src = event.target.result

        // Show the preview container by removing Bootstrap's "d-none" (display: none) class
        this.containerTarget.classList.remove("d-none")
      }

      // Start reading the file as a Data URL (base64-encoded string)
      // This triggers the asynchronous reading process
      // When it finishes, the "onload" event handler above will execute
      reader.readAsDataURL(file)

    } else {

      // If no file was selected OR the file isn't an image:
      // Hide the preview container by adding Bootstrap's "d-none" class
      this.containerTarget.classList.add("d-none")
    }

    // Flow Summary:
    // 1. Grab the file from the input element.
    // 2. Validate it's an image type.
    // 3. Create a FileReader to process the file.
    // 4. Set up the onload handler to display the result when reading completes.
    // 5. Start reading the file as a data URL (base64).
    // 6. Display the preview once the data URL is ready.
    // The key concept is that FileReader works asynchronously - you tell it to read the file with readAsDataURL(), and then it calls your onload function when it's done.

  }

}
