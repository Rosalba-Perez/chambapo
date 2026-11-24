# Chambapo

Aplicación de servicios del hogar a domicilio en Cartagena. Un cliente publica lo que necesita (plomería, electricidad, limpieza…), los técnicos cercanos reciben un aviso y envían su oferta, y el cliente elige a quién contratar. Después puede seguir al técnico en el mapa, chatear con él y calificar el servicio.

## Partes del proyecto

| Carpeta | Qué es | Tecnología |
|---|---|---|
| `mobile/` | App para clientes y técnicos | Flutter |
| `admin-web/` | Panel del administrador: estadísticas, mapas de calor, aprobación de técnicos y reportes | React + Vite |
| `backend/` | API con la lógica del negocio: crear solicitudes, buscar técnicos cercanos, enviar notificaciones y predecir contrataciones | Django REST Framework |
| `supabase/migrations/` | Base de datos, usuarios e inicio de sesión, chat y ubicación en tiempo real | Supabase (PostgreSQL) |
| `ml/` | Entrenamiento del modelo que predice si una solicitud terminará en contratación | scikit-learn |
| `k8s/`, `scripts/build-push.sh` | Despliegue en AWS con Kubernetes (EKS) | Docker, Kubernetes |
| `docker-compose.yml`, `nginx/` | Despliegue alternativo en un servidor con Docker | Docker Compose |

Además se usan Firebase para las notificaciones push y OpenStreetMap para los mapas.

## Cómo ejecutarlo en local

Necesitas Git, Python 3.12, Node 20, Flutter y una cuenta gratuita de Supabase.

1. **Configuración**: copia `.env.example` a `.env` y `admin-web/.env.example` a `admin-web/.env`, y llénalos con los datos de tu proyecto de Supabase. Cada variable indica dónde encontrar su valor.
2. **Base de datos**: en el SQL Editor de Supabase ejecuta en orden los archivos de `supabase/migrations/` (del `001` al `010`).
3. **API**:
   ```bash
   cd backend
   python -m venv .venv
   .venv\Scripts\activate          # en Linux/macOS: source .venv/bin/activate
   pip install -r requirements.txt
   python manage.py runserver
   ```
   La documentación de la API queda en http://localhost:8000/api/docs/
4. **Panel web**:
   ```bash
   cd admin-web
   npm install
   npm run dev                     # http://localhost:5173
   ```
5. **App móvil**: crea `mobile/env.json` con `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `API_URL`, y luego:
   ```bash
   cd mobile
   flutter pub get
   flutter run --dart-define-from-file=env.json
   ```

Para entrar al panel, el usuario debe tener el rol `admin` en la tabla `perfiles` de Supabase.

## Despliegue en AWS

La API, el panel y las tareas automáticas se despliegan en un clúster de **Amazon EKS**. La base de datos sigue en Supabase.

1. Crear en IAM un usuario con permisos para EC2, IAM, CloudFormation y EKS (la política está en `k8s/iam-policy.json`) y configurarlo con `aws configure`.
2. Construir y publicar las imágenes: `./scripts/build-push.sh <usuario-dockerhub> 1.0`
3. Crear el clúster:
   ```bash
   eksctl create cluster --name chambapo-cluster --region us-east-2 --nodes-min=3 --nodes-max=4 --instance-selector-vcpus=2 --instance-selector-memory=4 --version=1.35 --node-ami-family=AmazonLinux2023
   aws eks --region us-east-2 update-kubeconfig --name chambapo-cluster
   ```
4. Cargar la configuración y desplegar la API:
   ```bash
   kubectl apply -f k8s/00-namespace.yaml
   kubectl create secret generic chambapo-env --from-env-file=.env -n chambapo
   kubectl apply -f k8s/20-api.yaml -f k8s/30-cronjobs.yaml -f k8s/50-hpa.yaml
   kubectl get svc api -n chambapo        # copia la dirección pública (EXTERNAL-IP)
   ```
5. Desplegar el panel: en `k8s/40-admin-web.yaml` pon tus datos de Supabase y la dirección de la API, y luego:
   ```bash
   kubectl apply -f k8s/40-admin-web.yaml
   kubectl get svc admin-web -n chambapo
   ```
6. Publicar la versión web de la app (opcional):
   ```bash
   cd mobile
   flutter build web --release --dart-define-from-file=env.json   # con API_URL apuntando a la API de AWS
   cd ..
   docker build -t <usuario-dockerhub>/chambapo-app-web:1.0 -f mobile/Dockerfile.web mobile/build/web
   docker push <usuario-dockerhub>/chambapo-app-web:1.0
   kubectl apply -f k8s/60-app-web.yaml
   kubectl get svc app-web -n chambapo
   ```
7. Comprobar: abrir `http://<dirección-de-la-api>/api/docs/`, `http://<dirección-del-panel>/` y `http://<dirección-de-la-app>/`.
8. Al terminar, borrar todo para que no siga cobrando: `kubectl delete namespace chambapo` y `eksctl delete cluster --name chambapo-cluster --region us-east-2`.
