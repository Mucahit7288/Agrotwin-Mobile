package com.agrotwin.backend.service;

import com.agrotwin.backend.entity.EnergySchedule;
import com.agrotwin.backend.repository.EnergyScheduleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class EnergyScheduleService {

    private final EnergyScheduleRepository energyScheduleRepository;

    public List<EnergySchedule> getAll() {
        return energyScheduleRepository.findAll();
    }

    public List<EnergySchedule> getActive() {
        return energyScheduleRepository.findByAktifMi(1);
    }

    public List<EnergySchedule> getByCihaz(String cihaz) {
        return energyScheduleRepository.findByCihaz(cihaz);
    }

    public Optional<EnergySchedule> getById(Long id) {
        return energyScheduleRepository.findById(id);
    }

    public EnergySchedule save(EnergySchedule energySchedule) {
        return energyScheduleRepository.save(energySchedule);
    }

    public void deleteById(Long id) {
        energyScheduleRepository.deleteById(id);
    }
}
