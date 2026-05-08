terraform {
  backend "gcs" {
    bucket = "YOUR_BUCKET_NAME"  # TODO: Replace with your actual bucket name
    prefix = "YOUR_PREFIX"       # TODO: Replace with your actual prefix
  }
}