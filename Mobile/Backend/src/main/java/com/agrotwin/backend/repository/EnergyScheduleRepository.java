package com.agrotwin.backend.repository;

import com.agrotwin.backend.entity.EnergySchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EnergyScheduleRepository extends JpaRepository<EnergySchedule, Long> {

    List<EnergySchedule> findByCihaz(String cihaz);

    List<EnergySchedule> findByAktifMi(Integer aktifMi);
}
