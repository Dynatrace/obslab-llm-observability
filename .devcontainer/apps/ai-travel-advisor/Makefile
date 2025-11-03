IMAGE= shinojosa/ai-travel-advisor
VERSION = v1.0.0

build:
	docker build -t $(IMAGE):$(VERSION) .

push:
	docker push $(IMAGE):$(VERSION)

login:
	docker logout && docker login

runnginx:
	docker run -p 8080:80 -v /workspaces/enablement-gen-ai-llm-observability/app/public:/usr/share/nginx/html nginx

rollout:
	kubectl set image deployment/ai-travel-advisor ai-travel-advisor=$(IMAGE):$(VERSION) -n ai-travel-advisor