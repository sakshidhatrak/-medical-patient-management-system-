package com.medimanage.feature.template;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "print_template_fields")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PrintTemplateField {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "template_id", nullable = false)
    private PrintTemplate template;

    @Column(name = "field_key", nullable = false)
    private String fieldKey;

    @Column(name = "field_label", nullable = false)
    private String fieldLabel;

    @Column(nullable = false)
    private String section;

    @Column(name = "is_enabled", nullable = false)
    private boolean isEnabled = true;

    @Column(name = "display_order", nullable = false)
    private int displayOrder = 0;
}
