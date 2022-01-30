resource "scaleway_object_bucket" "proxy-volume" {
  name = "proxy-volume"
  acl  = "private"
}


resource "scaleway_object_bucket" "lobby1-volume" {
  name = "lobby1-volume"
  acl  = "private"
}

resource "scaleway_object_bucket" "bedwars-volume" {
  name = "bedwars-volume"
  acl  = "private"
}
