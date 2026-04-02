package com.agrotwin.backend.service;

import com.agrotwin.backend.entity.SensorLog;
import com.agrotwin.backend.repository.SensorLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class SensorLogService {

    private final SensorLogRepository sensorLogRepository;

    public List<SensorLog> getAll() {
        return sensorLogRepository.findAll();
    }

    public Optional<SensorLog> getLatest() {
        return sensorLogRepository.findTopByOrderByIdDesc();
    }

    public Optional<SensorLog> getById(Long id) {
        return sensorLogRepository.findById(id);
    }

    public SensorLog save(SensorLog sensorLog) {
        return sensorLogRepository.save(sensorLog);
    }

    public void deleteById(Long id) {
        sensorLogRepository.deleteById(id);
    }
}
