import std/[httpclient, json]

type
  SyncStorageClient* = object
    url*: string             # https://github.com/supabase/functions-js/blob/19512a44aa3b8e4ea89a825899a4e1b2223368af/src/FunctionsClient.ts#L27
    client: HttpClient       # https://github.com/supabase/functions-js/blob/19512a44aa3b8e4ea89a825899a4e1b2223368af/src/FunctionsClient.ts#L30

  AsyncStorageClient* = object
    url*: string             # https://github.com/supabase/functions-js/blob/19512a44aa3b8e4ea89a825899a4e1b2223368af/src/FunctionsClient.ts#L27
    client: AsyncHttpClient  # https://github.com/supabase/functions-js/blob/19512a44aa3b8e4ea89a825899a4e1b2223368af/src/FunctionsClient.ts#L30

proc close*(self: SyncStorageClient | AsyncStorageClient) {.inline.} = self.client.close()

proc newSyncStorageClient*(url, apiKey: string; maxRedirects = 9.Positive; timeout: -1..int.high = -1; proxy: Proxy = nil): SyncStorageClient =
  SyncStorageClient(url: url, client: newHttpClient(userAgent="supabase/storage3-nim v" & NimVersion, maxRedirects=maxRedirects, timeout=timeout, proxy=proxy,
    headers=newHttpHeaders({"Content-Type": "application/json", "Connection": "Keep-Alive", "DNT": "1", "Authorization": "Bearer " & apiKey})
  ))

proc newASyncStorageClient*(url, apiKey: string; maxRedirects = 9.Positive; timeout: -1..int.high = -1; proxy: Proxy = nil): AsyncStorageClient =
  AsyncStorageClient(url: url, client: newAsyncHttpClient(userAgent="supabase/storage3-nim v" & NimVersion, maxRedirects=maxRedirects, proxy=proxy,
    headers=newHttpHeaders({"Content-Type": "application/json", "Connection": "Keep-Alive", "DNT": "1", "Authorization": "Bearer " & apiKey})
  ))

template api(endpoint: string; metod: static[HttpMethod]; headers: HttpHeaders; body: openArray[(string, string)]): untyped =
  self.client.request(url = self.url & endpoint, metod = metod, headers = headers, body = if body.len > 0: $(%*body) else: "")

# Supabase Bucket API.

proc createBucket*(self: SyncStorageClient | AsyncStorageClient; id: string; public = false; allowedMimeTypes = @["*"]; fileSizeLimit = Positive.high): auto =
  api(endpoint = "/bucket", metod = HttpPost, headers = nil,
    body = {"id": id, "name": id, "public": public, "file_size_limit": fileSizeLimit, "allowed_mime_types": allowedMimeTypes})

proc emptyBucket*(self: SyncStorageClient | AsyncStorageClient; id: string): auto =
  api(endpoint = "/bucket/" & id & "/empty", metod = HttpPost, headers = nil, body = [])

proc updateBucket*(self: SyncStorageClient | AsyncStorageClient; id: string; public = false; allowedMimeTypes = @["*"]; fileSizeLimit = Positive.high): auto =
  api(endpoint = "/bucket/" & id, metod = HttpPut, headers = nil,
    body = {"id": id, "name": id, "public": public, "file_size_limit": fileSizeLimit, "allowed_mime_types": allowedMimeTypes})

proc getBucket*(self: SyncStorageClient | AsyncStorageClient; id: string): auto =
  api(endpoint = "/bucket/" & id, metod = HttpGet, headers = nil)

proc deleteBucket*(self: SyncStorageClient | AsyncStorageClient; id: string): auto =
  api(endpoint = "/bucket/" & id, metod = HttpDelete, headers = nil)

proc listBuckets*(self: SyncStorageClient | AsyncStorageClient): auto =
  api(endpoint = "/bucket", metod = HttpGet, headers = nil, body = [])

# Supabase File API.

proc list*(self: SyncStorageClient | AsyncStorageClient; path, id: string; limit = Positive.high; offset = 0.Natural; search = ""; order = "asc"): auto =
  api(endpoint = "/object/list/" & id, metod = HttpPost, headers = nil, body = {"prefix": path, "limit": limit, "offset": offset, "order": order})

proc move*(self: SyncStorageClient | AsyncStorageClient; fromPath, toPath, id: string): auto =
  api(endpoint = "/object/move", metod = HttpPost, headers = nil, body = {"bucketId": id, "sourceKey": fromPath, "destinationKey": toPath})

proc copy*(self: SyncStorageClient | AsyncStorageClient; fromPath, toPath, id: string): auto =
  api(endpoint = "/object/copy", metod = HttpPost, headers = nil, body = {"bucketId": id, "sourceKey": fromPath, "destinationKey": toPath})

proc remove*(self: SyncStorageClient | AsyncStorageClient; paths: seq[string]; id: string): auto =
  api(endpoint = "/object/" & id, metod = HttpDelete, headers = nil, body = {"prefixes": paths})

proc createSignedUrl*(self: SyncStorageClient | AsyncStorageClient; path: string; expiresIn = Positive.high; download = false): auto =
  api(endpoint = "/object/upload/sign/" & id & '/' & path, headers = nil, metod = HttpPost)

proc createSignedUrls*(self: SyncStorageClient | AsyncStorageClient; paths: seq[string]; expiresIn = Positive.high; download = false): auto =
  api(endpoint = "/object/sign/" & id, metod = HttpPost, body = {"paths": paths, "expiresIn": expiresIn, "download": download})

proc createSignedUploadUrl*(self: SyncStorageClient | AsyncStorageClient; path: string): auto =
  api(endpoint = "/object/upload/sign/" & id & '/' & path, metod = HttpPost, headers = nil, body = [])

# Complex code below

proc uploadToSignedUrl*(self: SyncStorageClient | AsyncStorageClient; path, fileBody, token: string; cacheControl = 3600.Positive; upsert = false ): auto =
  api(endpoint = "/object/upload/sign/" & id & '/' & path, metod = HttpPost, headers = {"Cache-Control": "max-age=" & $cacheControl}, body = [])

proc getPublicUrl*(self: SyncStorageClient | AsyncStorageClient; path: string; download = false): auto =
  api(endpoint = "/object/upload/sign/" & id & '/' & path, metod = HttpPost, headers = {"Cache-Control": "max-age=" & $cacheControl}, body = [])

proc download*(self: SyncStorageClient | AsyncStorageClient; path, id: string): auto =
  api(endpoint = "/object/" & id '/' & path, metod = HttpGet, headers = nil, body = [])

proc upload*(self: SyncStorageClient | AsyncStorageClient; path, fileBody: string; cacheControl = 3600.Positive): auto =
  api(endpoint = "/object/" & id '/' & path, metod = HttpPost, headers = {"Cache-Control": "max-age=" & $cacheControl}, body = fileBody)

proc update*(self: SyncStorageClient | AsyncStorageClient; path, fileBody: string; cacheControl = 3600.Positive; upsert = false): auto =
  api(endpoint = "/object/upload/sign/" & id & '/' & path, metod = HttpPut, headers = {"Cache-Control": "max-age=" & $cacheControl, "x-upsert": $upsert}, body = [])


# https://supabase.com/docs/reference/javascript/storage-from-move
