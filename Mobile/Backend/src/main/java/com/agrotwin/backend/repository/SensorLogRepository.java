package com.agrotwin.backend.repository;

import com.agrotwin.backend.entity.SensorLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SensorLogRepository extends JpaRepository<SensorLog, Long> {

    /** En son eklenen kayıt (AUTO id sırası; timestamp string sıralamasına bağlı değil). */
    Optional<SensorLog> findTopByOrderByIdDesc();
}
