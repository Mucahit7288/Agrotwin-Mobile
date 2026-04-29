package com.agrotwin.backend.controller;

import com.agrotwin.backend.entity.SensorLog;
import com.agrotwin.backend.service.SensorLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/sensors")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class SensorLogController {

    private final SensorLogService sensorLogService;

    @GetMapping
    public ResponseEntity<List<SensorLog>> getAll() {
        return ResponseEntity.ok(sensorLogService.getAll());
    }

    @GetMapping("/latest")
    public ResponseEntity<SensorLog> getLatest() {
        return sensorLogService.getLatest()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}")
    public ResponseEntity<SensorLog> getById(@PathVariable Long id) {
        return sensorLogService.getById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<SensorLog> create(@RequestBody SensorLog sensorLog) {
        return ResponseEntity.ok(sensorLogService.save(sensorLog));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        sensorLogService.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
