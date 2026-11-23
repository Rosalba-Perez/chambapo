from django.urls import path
from . import views
urlpatterns = [path("predict/", views.Predict.as_view()), path("info/", views.Info.as_view())]
