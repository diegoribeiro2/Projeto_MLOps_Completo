# data lake onde os dados serão recuperados

resource "aws_s3_bucket" "data-lake" {
    bucket = "data-lake-${random_string.random.result}"
}

locals {
  object_source = "data/sentiment_dataset.csv"
}

resource "aws_s3_object" "file_upload" {
  bucket      = aws_s3_bucket.data-lake.bucket
  key         = "sentiment_dataset.csv"
  source      = local.object_source
  source_hash = filemd5(local.object_source)
}