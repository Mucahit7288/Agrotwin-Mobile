package com.agrotwin.backend.repository;

import com.agrotwin.backend.entity.PriceForecast;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PriceForecastRepository extends JpaRepository<PriceForecast, Long> {

    /** En son eklenen kayıt (AUTO id sırası). */
    Optional<PriceForecast> findTopByOrderByIdDesc();

    List<PriceForecast> findByPahaliMi(Integer pahaliMi);

    List<PriceForecast> findByUcuzMu(Integer ucuzMu);
}
