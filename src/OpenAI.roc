import pf.Http

OpenAI := [].{
	Error : [TransportError(Str), HttpError(U16, Str), InvalidUnicode, InvalidResponse, ResponseNotCompleted({ status : Str, reason : Str }), MissingContent, MissingText, Refused, NoText]
	Output : { type : Str, content ?: List({ type : Str, text ?: Str }) }
	Response : { status : Str, output : List(Output) }

	request : Str, Str, Str -> Http.Request
	request = |key, model, message| {
		payload : { model : Str, input : Str, store : Bool, reasoning : { effort : Str } }
		payload = { model, input: message, store: False, reasoning: { effort: "medium" } }
		{
			method: "POST",
			url: "https://api.openai.com/v1/responses",
			headers: [
				{ name: "Authorization", value: "Bearer ${key}" },
				{ name: "Content-Type", value: "application/json" },
			],
			body: Json.to_str(payload).to_utf8(),
			timeout_ms: 60000,
		}
	}

	send! : Str, Str, Str => Try(Str, Error)
	send! = |key, model, message| {
		http_response = Http.send!(request(key, model, message)).map_err(|error| TransportError(error))?
		decode(http_response.status, http_response.body)
	}

	decode : U16, List(U8) -> Try(Str, Error)
	decode = |status, body| {
		json = Str.from_utf8(body).map_err(|_| InvalidUnicode)?
		if status < 200 or status >= 300 {
			error : Try({ error : { message : Str } }, _)
			error = Json.parse(json)
			return match error {
				Ok(value) => Err(HttpError(status, value.error.message))
				Err(_) => Err(HttpError(status, "Unexpected error response"))
			}
		}
		parsed : Try(Response, _)
		parsed = Json.parse(json)
		response = parsed.map_err(|_| InvalidResponse)?
		if response.status != "completed" {
			details : Try({ incomplete_details : { reason : Str } }, _)
			details = Json.parse(json)
			reason = match details {
				Ok(value) => value.incomplete_details.reason
				Err(_) => ""
			}
			return Err(ResponseNotCompleted({ status: response.status, reason }))
		}
		var $parts = []
		for output in response.output {
			if output.type == "message" {
				content = output.?content.map_err(|_| MissingContent)?
				for part in content {
					match part.type {
						"output_text" => {
							text = part.?text.map_err(|_| MissingText)?
							$parts = $parts.append(text)
						}
						"refusal" => return Err(Refused)
						_ => {}
					}
				}
			}
		}
		if $parts.is_empty() {
			Err(NoText)
		} else {
			Ok(Str.join_with($parts, ""))
		}
	}
}

expect {
	message = "Hello \"world\"\n🦜"
	request = OpenAI.request("test-key", "test-model", message)
	body : Try({ model : Str, input : Str, store : Bool, reasoning : { effort : Str } }, _)
	body = Json.parse(Str.from_utf8(request.body) ?? "")
	request.method == "POST" and
		request.url == "https://api.openai.com/v1/responses" and
			request.headers == [
				{ name: "Authorization", value: "Bearer test-key" },
				{ name: "Content-Type", value: "application/json" },
			] and
				body == Ok({ model: "test-model", input: message, store: False, reasoning: { effort: "medium" } })
}

expect OpenAI.decode(200, "{\"id\":\"resp_test\",\"status\":\"completed\",\"incomplete_details\":null,\"output\":[{\"type\":\"reasoning\",\"summary\":[]},{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hello \"},{\"type\":\"output_text\",\"text\":\"🦜\"}]}]}".to_utf8()) == Ok("Hello 🦜")

expect OpenAI.decode(401, "{\"error\":{\"message\":\"Invalid API key\",\"type\":\"invalid_request_error\"}}".to_utf8()) == Err(HttpError(401, "Invalid API key"))

expect OpenAI.decode(502, "Bad Gateway".to_utf8()) == Err(HttpError(502, "Unexpected error response"))

expect OpenAI.decode(200, "not json".to_utf8()) == Err(InvalidResponse)

expect OpenAI.decode(200, [255]) == Err(InvalidUnicode)

expect OpenAI.decode(200, "{\"status\":\"incomplete\",\"output\":[],\"incomplete_details\":{\"reason\":\"max_output_tokens\"}}".to_utf8()) == Err(ResponseNotCompleted({ status: "incomplete", reason: "max_output_tokens" }))

expect OpenAI.decode(200, "{\"status\":\"failed\",\"output\":[],\"incomplete_details\":null}".to_utf8()) == Err(ResponseNotCompleted({ status: "failed", reason: "" }))

expect OpenAI.decode(200, "{\"status\":\"incomplete\",\"output\":[]}".to_utf8()) == Err(ResponseNotCompleted({ status: "incomplete", reason: "" }))

expect OpenAI.decode(200, "{\"status\":\"completed\",\"output\":[]}".to_utf8()) == Err(NoText)

expect OpenAI.decode(200, "{\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"refusal\",\"refusal\":\"No\"}]}]}".to_utf8()) == Err(Refused)
