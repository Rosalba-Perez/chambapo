select c.nombre categoria, coalesce(s.barrio, 'desconocido') barrio, s.presupuesto, s.dia_semana,
       s.franja_horaria::text franja_horaria, s.dias_anticipacion,
       (select count(*) from postulaciones p where p.solicitud_id = s.id and p.creado_en <= s.creado_en + interval '24 hours') num_postulaciones_24h,
       coalesce((select extract(epoch from min(p.creado_en) - s.creado_en)/60 from postulaciones p where p.solicitud_id = s.id), 1440) tiempo_primera_postulacion,
       (select min(p.precio) from postulaciones p where p.solicitud_id = s.id) / nullif(s.presupuesto, 0) precio_relativo,
       s.contratada::int contratada
from solicitudes s join categorias c on c.id = s.categoria_id
where s.contratada is not null;
