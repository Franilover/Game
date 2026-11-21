extends "res://scripts/infrastructure/garlia_auth.gd"

var simular_offline: bool = true
var llamadas_refresh: int = 0
var llamadas_perfil: int = 0


func _hacer_peticion(
	url: String,
	metodo: HTTPClient.Method,
	_headers: PackedStringArray,
	_cuerpo: String = ""
) -> Variant:
	if simular_offline:
		return {
			"result_code": HTTPRequest.RESULT_REQUEST_FAILED,
			"response_code": 0,
			"body": ""
		}

	if url.contains("/auth/v1/token"):
		llamadas_refresh += 1
		return {
			"result_code": HTTPRequest.RESULT_SUCCESS,
			"response_code": 200,
			"body": JSON.stringify({
				"access_token": "access-token-rotated",
				"refresh_token": "refresh-token-rotated",
				"user": {
					"id": "offline-restore-user",
					"email": "offline@example.test"
				}
			})
		}

	if url.contains("/rest/v1/perfiles"):
		llamadas_perfil += 1
		return {
			"result_code": HTTPRequest.RESULT_SUCCESS,
			"response_code": 200,
			"body": JSON.stringify([{
				"id": "offline-restore-user",
				"username": "OfflineProbe",
				"rol": "user"
			}])
		}

	return {
		"result_code": HTTPRequest.RESULT_REQUEST_FAILED,
		"response_code": 0,
		"body": ""
	}
